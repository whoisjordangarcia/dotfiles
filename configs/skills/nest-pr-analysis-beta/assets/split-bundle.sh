#!/usr/bin/env bash
# split-bundle.sh — Split the compute-stats.jq output into the six per-section
# JSON files consumed by dashboard-template.html, and join PR-level iteration
# data (comments/commits/changed_files) from the REST per-PR fetch.
#
# Usage:
#   split-bundle.sh <stats_bundle.json> <iter_all.json> <out_dir>
#
# Inputs:
#   stats_bundle.json  - output of `jq -f compute-stats.jq nest_all.json`
#   iter_all.json      - output of `jq -s . /tmp/pr_iter/*.json`
#   out_dir            - directory to write the six JSON files
#
# Outputs (in <out_dir>/):
#   dashboard_data.json
#   timing.json
#   areas.json
#   slowest.json
#   iteration.json
#   pr_index.json

set -euo pipefail

BUNDLE=${1:?stats bundle path required}
ITER=${2:?iter all path required}
OUT=${3:?output dir required}
mkdir -p "$OUT"

jq '.dashboard_data' "$BUNDLE" > "$OUT/dashboard_data.json"
jq '.timing'         "$BUNDLE" > "$OUT/timing.json"
jq '.areas'          "$BUNDLE" > "$OUT/areas.json"
jq '.slowest'        "$BUNDLE" > "$OUT/slowest.json"

# Merge iteration counts and CI durations into pr_index.
# Optional 4th arg: CI bundle (output of fetch_ci.sh, see SKILL.md Step 3b).
# The CI bundle has both ci_min (longest single job) and runs[] (per-step
# durations) per PR — both are needed for the dashboard.
CI_BUNDLE=${4:-}
jq -s '
  (.[0].pr_index) as $idx |
  (.[1])         as $iter |
  (if (. | length) > 2 then .[2] else [] end) as $cidata |
  ($iter   | map({(.number|tostring): .}) | add) as $imap |
  ($cidata | map({(.number|tostring): .}) | add // {}) as $cmap |
  $idx | map(. + {
    cmt: (($imap[(.n|tostring)].comments // 0) + ($imap[(.n|tostring)].review_comments // 0)),
    rc:  ($imap[(.n|tostring)].review_comments // 0),
    co:  ($imap[(.n|tostring)].commits // 0),
    cf:  ($imap[(.n|tostring)].changed_files // 0),
    ci:  ($cmap[(.n|tostring)].ci_min // null),
    cis: ([($cmap[(.n|tostring)].runs // [])[] | select(.sec >= 0) | {n: .name, s: .sec}])
  })
' "$BUNDLE" "$ITER" ${CI_BUNDLE:+"$CI_BUNDLE"} > "$OUT/pr_index.json"

# Compute iteration stats from the merged data
jq '
  def stats($arr):
    ($arr|sort) as $s | ($s|length) as $n |
    if $n==0 then null
    else { n:$n, p50:$s[($n*0.5|floor)], p75:$s[($n*0.75|floor)],
           p90:$s[($n*0.9|floor)], max:$s[-1],
           mean:(($s|add)/$n*10|round/10) } end;

  {
    review_comments: stats([.[].review_comments // 0]),
    issue_comments:  stats([.[].comments // 0]),
    total_comments:  stats([.[] | (.comments//0)+(.review_comments//0)]),
    commits:         stats([.[].commits // 0]),
    changed_files:   stats([.[].changed_files // 0]),
    comment_buckets: (
      [.[] | (.comments//0)+(.review_comments//0)] as $a | {
        "0":     ($a|map(select(.==0))|length),
        "1-2":   ($a|map(select(.>=1 and .<=2))|length),
        "3-5":   ($a|map(select(.>=3 and .<=5))|length),
        "6-10":  ($a|map(select(.>=6 and .<=10))|length),
        "11-20": ($a|map(select(.>=11 and .<=20))|length),
        "21-50": ($a|map(select(.>=21 and .<=50))|length),
        ">50":   ($a|map(select(.>50))|length)
      }
    ),
    commit_buckets: (
      [.[].commits // 0] as $a | {
        "1":     ($a|map(select(.==1))|length),
        "2-3":   ($a|map(select(.>=2 and .<=3))|length),
        "4-7":   ($a|map(select(.>=4 and .<=7))|length),
        "8-15":  ($a|map(select(.>=8 and .<=15))|length),
        "16-30": ($a|map(select(.>=16 and .<=30))|length),
        ">30":   ($a|map(select(.>30))|length)
      }
    )
  }
' "$ITER" > "$OUT/iteration_partial.json"

# Combine size buckets from main bundle (need additions/deletions from PR data)
# and the most-iterated/most-commits tables (need to join with PR titles)
jq -s '
  (.[0].pr_index) as $idx |
  (.[1])         as $iter |
  (.[2])         as $part |
  ($iter | map({(.number|tostring): .}) | add) as $imap |
  ($idx | map({(.n|tostring): .}) | add) as $pidx |

  $part + {
    size_buckets: (
      [$idx[] | (.ad)+(.de)] as $a | {
        "XS (<10)":      ($a|map(select(.<10))|length),
        "S (10-50)":     ($a|map(select(.>=10 and .<50))|length),
        "M (50-200)":    ($a|map(select(.>=50 and .<200))|length),
        "L (200-500)":   ($a|map(select(.>=200 and .<500))|length),
        "XL (500-1500)": ($a|map(select(.>=500 and .<1500))|length),
        "XXL (>1500)":   ($a|map(select(.>=1500))|length)
      }
    ),
    most_iterated: (
      [$iter[] |
        ($pidx[(.number|tostring)]) as $p |
        select($p) | {
          number: .number,
          title: $p.t,
          author: $p.a,
          comments: ((.comments//0)+(.review_comments//0)),
          commits: (.commits//0),
          changed_files: (.changed_files//0)
        }]
      | sort_by(-.comments) | .[:10]
    ),
    most_commits: (
      [$iter[] |
        ($pidx[(.number|tostring)]) as $p |
        select($p) | {
          number: .number, title: $p.t, author: $p.a,
          commits: (.commits // 0)
        }]
      | sort_by(-.commits) | .[:10]
    )
  }
' "$BUNDLE" "$ITER" "$OUT/iteration_partial.json" > "$OUT/iteration.json"

rm "$OUT/iteration_partial.json"

echo "Wrote: $OUT/{dashboard_data,timing,areas,slowest,iteration,pr_index}.json"
