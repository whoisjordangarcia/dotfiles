# compute-stats.jq — Single jq program that emits the full stats bundle for
# the Nest PR Analysis dashboard. Input: array of PRs from `gh pr list ...`
# Output: object with six top-level keys mapping to the six section JSON files.
#
# Usage:
#   jq -f compute-stats.jq /tmp/nest_all.json > /tmp/stats_bundle.json
#
# Then split via assets/split-bundle.sh, optionally joining with /tmp/nest_iter_all.json.

def is_bot($u): ($u | test("^(cursor|copilot|app/|dependabot|blacksmith|github-actions|eng$)"));

def reviewers:
  ((.reviewRequests // []) | map(.login // .name // empty)) +
  ((.reviews // [])        | map(.author.login // empty))
  | unique | map(select(. != null and . != ""));

def human_reviewers: reviewers | map(select(is_bot(.) | not));

def hrs($a;$b): (($b|fromdateiso8601) - ($a|fromdateiso8601)) / 3600;

def first_human_review_at:
  [(.reviews // [])[]
   | select(.author.login as $u | (is_bot($u) | not))
   | .submittedAt] | sort | .[0] // null;

def first_human_approval_at:
  [(.reviews // [])[]
   | select(.state=="APPROVED" and (.author.login as $u | (is_bot($u)|not)))
   | .submittedAt] | sort | .[0] // null;

# Domain-specific area classifier for Nest healthcare-genomics product.
# Order matters — put the more specific matches earlier.
def area:
  (.title | ascii_downcase) as $t |
  if   $t | test("^revert\\b|\\brevert\\b") then "revert"
  elif $t | test("release\\b|patch\\b|^merge stg|merge stg into|merge release|release candidate|2\\.[0-9]+\\.[0-9]+|backport|npm package update|version bump") then "release/merge"
  elif $t | test("care.?plan|care research|care step|evidence to care") then "care-plan"
  elif $t | test("ai assistant|chat ?bot|llm|\\bai\\b summary|ai summaries|clinical ai|ai follow") then "clinical-ai"
  elif $t | test("clinvar|gene.?findings|\\bgenepal\\b|results overview|variant|gene.?pal|ambry|gene findings") then "clinical-results"
  elif $t | test("pedigree|relative|relationship|adopted|family.?(history|sharing|size)|proband|top.?level person") then "pedigree"
  elif $t | test("\\bcra\\b|breast density|cancer (subtype|risk)|kidney|renal|sarcoma|tyrer|cuzick") then "cancer-risk-assessment"
  elif $t | test("assessment|peds|inheritance.?field|insurance|dob|date.?(mask|format)") then "assessments/forms"
  elif $t | test("athena|advancedmd|\\becw\\b|smart on fhir|\\bfhir\\b|\\bepic\\b|smart.?launch|practitioner") then "ehr-integration"
  elif $t | test("\\bmyome\\b|myriad|\\border\\b") then "lab-orders"
  elif $t | test("story|questionnaire|narration|storyplayer|story.?(editor|player)|learn page|article drawer|article|narrate") then "stories/questionnaires"
  elif $t | test("\\bconsent\\b") then "consents"
  elif $t | test("\\btodo\\b|magic link") then "patient-todos"
  elif $t | test("yoda") then "yoda(frontend)"
  elif $t | test("patient.?navigator|navigator") then "patient-navigator"
  elif $t | test("retool") then "retool"
  elif $t | test("provider.?portal") then "provider-portal"
  elif $t | test("workflow|\\bhook\\b") then "workflows/hooks"
  elif $t | test("auth\\b|login|cognito|frontegg|sign.?in|sign.?up|guard|redirect|open redirect|launch flow") then "auth/security"
  elif $t | test("scheduling|schedule|appointment") then "scheduling"
  elif $t | test("care.?template|note template|template.?import") then "care-templates"
  elif $t | test("posthog|analytics|tracking|activity feed|event\\b") then "analytics/events"
  elif $t | test("sentry|\\berror\\b|logging|observability|notification|slack|email") then "observability/notifications"
  elif $t | test("graphql|resolver|prisma|migration|\\bsql\\b|lambda|backend|\\bapi\\b") then "backend/api"
  elif $t | test("terraform|\\binfra\\b|deploy|github.action|docker|\\bnx\\b|\\bci\\b|cypress|jenkins|codespace|node modules|dev env") then "infra/ci"
  elif $t | test("\\be2e\\b|playwright|spec\\b|vitest|jest|\\btest\\b") then "tests"
  elif $t | test("readme|\\bdocs?\\b|documentation") then "docs"
  elif $t | test("\\bdeps\\b|bump|upgrade|dependabot|prettier|lint|formatting|feature flag|stale\\b") then "chore/cleanup"
  elif $t | test("\\bpdf\\b|document|sftp|export") then "documents/pdf"
  elif $t | test("\\bmrn\\b|patient list|patient filter|patient table|patient.?page|patients search|search bar") then "patient-management"
  elif $t | test("language|spanish|i18n|translation|locale") then "i18n"
  elif $t | test("rule engine|rule|mapping") then "rules-engine"
  elif $t | test("logo|pixel|drawer|fullscreen|empty state|width|responsive|label|ux\\b|ui\\b") then "ui/visual"
  else "other" end;

def stats($arr):
  ($arr|sort) as $s | ($s|length) as $n |
  if $n==0 then null
  else { n:$n,
         p50:$s[($n*0.5|floor)], p75:$s[($n*0.75|floor)],
         p90:$s[($n*0.9|floor)], max:$s[-1],
         mean:(($s|add)/$n*10|round/10)
       } end;

def fmt_hrs:
  if .==null then null
  else { n,
         p50_h:(.p50*100|round/100), p75_h:(.p75*100|round/100),
         p90_h:(.p90*100|round/100), max_h:(.max*100|round/100),
         mean_h:(.mean*100|round/100),
         p50_d:(.p50/24*10|round/10), p90_d:(.p90/24*10|round/10) }
  end;

# === Bundle output ===
. as $prs |

# All metrics-per-PR
($prs | map({
   number, title,
   author: .author.login,
   state, createdAt, mergedAt,
   ttfr: (if first_human_review_at then hrs(.createdAt; first_human_review_at) else null end),
   ttfa: (if first_human_approval_at then hrs(.createdAt; first_human_approval_at) else null end),
   ttm:  (if .mergedAt then hrs(.createdAt; .mergedAt) else null end),
   approve_to_merge: (
     if .mergedAt and first_human_approval_at
     then hrs(first_human_approval_at; .mergedAt) else null end
   )
 })) as $m |

{
  # ---- dashboard_data ----
  dashboard_data: {
    summary: {
      total: ($prs|length),
      merged: ($prs|map(select(.state=="MERGED"))|length),
      open:   ($prs|map(select(.state=="OPEN"))|length),
      closed: ($prs|map(select(.state=="CLOSED"))|length),
      avg_additions: (($prs|map(.additions)|add)/($prs|length)|floor),
      avg_deletions: (($prs|map(.deletions)|add)/($prs|length)|floor),
      prs_no_human_reviewer:
        ($prs|map(select(human_reviewers|length==0))|length)
    },
    by_area: ($prs | group_by(area) | map({k:(.[0]|area), v:length}) | sort_by(-.v)),
    by_state: [
      {k:"MERGED", v:($prs|map(select(.state=="MERGED"))|length)},
      {k:"CLOSED", v:($prs|map(select(.state=="CLOSED"))|length)},
      {k:"OPEN",   v:($prs|map(select(.state=="OPEN"))|length)}
    ],
    top_reviewers: (
      [$prs[]|human_reviewers[]]
      | group_by(.) | map({k:.[0], v:length}) | sort_by(-.v)
    ),
    bot_reviewers: (
      [$prs[]|reviewers[] | select(is_bot(.))]
      | group_by(.) | map({k:.[0], v:length}) | sort_by(-.v)
    ),
    top_authors: (
      $prs | group_by(.author.login)
      | map({k:.[0].author.login, v:length}) | sort_by(-.v) | .[:12]
    ),
    by_day: (
      $prs | group_by(.createdAt[0:10])
      | map({k:.[0].createdAt[0:10], v:length}) | sort_by(.k)
    )
  },

  # ---- timing ----
  timing: {
    time_to_first_review:
      ([$m[].ttfr | select(.!=null and .>=0)] | stats(.) | fmt_hrs),
    time_to_first_approval:
      ([$m[].ttfa | select(.!=null and .>=0)] | stats(.) | fmt_hrs),
    time_to_merge:
      ([$m[].ttm  | select(.!=null and .>=0)] | stats(.) | fmt_hrs),
    approval_to_merge:
      ([$m[].approve_to_merge | select(.!=null and .>=0)] | stats(.) | fmt_hrs),
    ttm_distribution: (
      [$m[].ttm | select(.!=null and .>=0)] as $a | {
        "<1h":     ($a|map(select(.<1))|length),
        "1-4h":    ($a|map(select(.>=1 and .<4))|length),
        "4-12h":   ($a|map(select(.>=4 and .<12))|length),
        "12-24h":  ($a|map(select(.>=12 and .<24))|length),
        "1-2d":    ($a|map(select(.>=24 and .<48))|length),
        "2-7d":    ($a|map(select(.>=48 and .<168))|length),
        "1-2w":    ($a|map(select(.>=168 and .<336))|length),
        ">2w":     ($a|map(select(.>=336))|length)
      }
    ),
    by_author_ttm: (
      [$m[] | select(.ttm!=null)]
      | group_by(.author)
      | map({author:.[0].author, n:length,
             median_hrs: ((map(.ttm)|sort)[length/2|floor]*10|round/10)})
      | sort_by(-.n) | .[:10]
    )
  },

  # ---- areas ----
  areas: (
    ([$prs|group_by(.author.login)|map({k:.[0].author.login,v:length})|sort_by(-.v)|.[:8] | .[].k]) as $topAuthors |
    ($prs | group_by(area) | map({area:(.[0]|area), count:length}) | sort_by(-.count) | map(.area)) as $areas |
    {
      areas: $areas,
      top_authors: $topAuthors,
      matrix: (
        reduce $prs[] as $pr ({};
          ($pr|area) as $a |
          $pr.author.login as $au |
          (if ($topAuthors | index($au)) then $au else "others" end) as $bucket |
          .[$a][$bucket] = ((.[$a][$bucket] // 0) + 1)
        )
      ),
      by_area_engineers: (
        $prs | group_by(area)
        | map({
            area: (.[0]|area),
            count: length,
            merged: (map(select(.state=="MERGED"))|length),
            median_ttm_hrs: (
              [.[] | select(.mergedAt) | hrs(.createdAt; .mergedAt)] as $arr |
              if ($arr|length)==0 then null
              else (($arr|sort)[($arr|length)/2|floor] * 10 | round / 10)
              end
            ),
            authors:   ([.[].author.login] | group_by(.) | map({k:.[0],v:length}) | sort_by(-.v) | .[:6]),
            reviewers: ([.[]|human_reviewers[]] | group_by(.) | map({k:.[0],v:length}) | sort_by(-.v) | .[:6])
          })
        | sort_by(-.count)
      )
    }
  ),

  # ---- slowest ----
  slowest: (
    [$prs[] | select(.mergedAt)
     | { number, title, author:.author.login,
         days:((hrs(.createdAt;.mergedAt))/24*10|round/10) }]
    | sort_by(-.days) | .[:10]
  ),

  # ---- pr_index (flat per-PR for the click-drilldown modal) ----
  # NOTE: iteration counts (cmt/rc/co/cf) are merged in via split-bundle.sh from
  # the REST per-PR data — the GraphQL bulk query cannot include them.
  pr_index: ($prs | map({
    n: .number,
    t: .title,
    a: .author.login,
    s: .state,
    ar: area,
    c: .createdAt,
    m: .mergedAt,
    ad: (.additions // 0),
    de: (.deletions // 0),
    r: human_reviewers,
    dr: (.isDraft // false),
    ttm:  (if .mergedAt               then ((hrs(.createdAt; .mergedAt))*10|round/10) else null end),
    ttfr: (if first_human_review_at   then ((hrs(.createdAt; first_human_review_at))*10|round/10) else null end),
    ttfa: (if first_human_approval_at then ((hrs(.createdAt; first_human_approval_at))*10|round/10) else null end),
    rt: (
      .createdAt as $c |
      (((.reviews // [])
        | map(select(.author.login as $u | (is_bot($u) | not)))
        | group_by(.author.login)
        | map({(.[0].author.login):
            ((map(.submittedAt) | sort | .[0]) as $t |
              if $t then (hrs($c; $t) * 10 | round / 10) else null end)
          })
        | add) // {})
    ),
    # ci is filled in by split-bundle.sh from the per-PR check-runs fetch.
    ci: null
  }))
}
