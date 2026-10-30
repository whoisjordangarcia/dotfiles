local colors = require("colors")
local settings = require("settings")
local popup_manager = require("items.widgets.popup_manager")
local style = require("items.widgets.popup_style")

-- Never io.popen this during load: it empties the whole bar. Resolved async; the widget starts hidden.
local ENV_CHECK = "bash -c 'source $HOME/dev/dotfiles/script/common/dot_env.sh && dot_resolve_env' 2>/dev/null"
local is_work = false

-- Direct requests only: team requests (review-requested:) are several times larger and mostly not yours.
local REQUESTED = "is:pr is:open draft:false repo:Nest-Genomics/nest user-review-requested:@me"
local MINE = "is:pr is:open repo:Nest-Genomics/nest author:@me sort:updated-desc"
local BROWSER = "Brave Browser"
local MAX_ROWS = 8

-- Review waits run from your latest review request, so a re-request resets them; your PRs age from creation.
-- Emits "total\t<n>", then "R\t<seconds>\t<url>\t<title>" per request and
-- "M\t<draft|approved|open>\t<seconds>\t<url>\t<title>" per PR of yours; the tag stops sbar.exec JSON-parsing a bare number.
-- reviewDecision stays null on bases without branch protection (stacked PRs), so approval falls back to the reviews.
-- launchd's PATH lacks Homebrew, hence the prefix.
local FETCH = "PATH=/opt/homebrew/bin:$PATH gh api graphql -f query='query { viewer { login } "
	.. 'requested: search(query: "' .. REQUESTED .. '", type: ISSUE, first: ' .. MAX_ROWS .. ") { issueCount "
	.. "nodes { ... on PullRequest { title url createdAt "
	.. "timelineItems(itemTypes: [REVIEW_REQUESTED_EVENT], last: 20) { nodes { ... on ReviewRequestedEvent "
	.. "{ createdAt requestedReviewer { ... on User { login } } } } } } } } "
	.. 'mine: search(query: "' .. MINE .. '", type: ISSUE, first: ' .. MAX_ROWS .. ") { "
	.. "nodes { ... on PullRequest { title url createdAt isDraft reviewDecision "
	.. "latestOpinionatedReviews(first: 20) { nodes { state } } } } } }' "
	.. "--jq '.data.viewer.login as $me | .data | \"total\\t\\(.requested.issueCount)\", "
	.. "(.requested.nodes[] | .createdAt as $opened "
	.. "| ([.timelineItems.nodes[] | select(.requestedReviewer.login == $me) | .createdAt] | last // $opened) as $since "
	.. "| \"R\\t\\(now - ($since | fromdateiso8601) | floor)\\t\\(.url)\\t\\(.title)\"), "
	.. "(.mine.nodes[] | [.latestOpinionatedReviews.nodes[].state] as $reviews "
	.. "| (.reviewDecision == \"APPROVED\" or (.reviewDecision == null and ($reviews | any(. == \"APPROVED\")) "
	.. "and ($reviews | all(. != \"CHANGES_REQUESTED\")))) as $approved "
	.. "| \"M\\t\\(if .isDraft then \"draft\" elif $approved then \"approved\" else \"open\" end)\\t"
	.. "\\(now - (.createdAt | fromdateiso8601) | floor)\\t\\(.url)\\t\\(.title)\")' 2>/dev/null"

-- Must match claude.lua's placement so this lands immediately after it.
local POS = require("scale").notch and "left" or "center"

local lead = sbar.add("item", "widgets.reviews.lead", { position = POS, width = 6, drawing = false })

local reviews = sbar.add("item", "widgets.reviews", {
	position = POS,
	drawing = false,
	icon = {
		string = "\u{F407}",
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Regular"],
			size = 11.0,
		},
		color = colors.chrome.icon,
		padding_right = 4,
	},
	label = {
		string = "—",
		font = { family = settings.font.numbers, size = 11.0 },
		color = colors.chrome.label,
	},
	background = { drawing = false },
	-- One GraphQL request per poll or popup open; far under the 5000 points/hour budget.
	update_freq = 300,
	padding_left = 6,
	padding_right = 6,
})

local bracket = sbar.add("bracket", "widgets.reviews.bracket", { reviews.name }, {
	background = { color = colors.bg1 },
	popup = { align = "center", height = style.height },
})

local spacer = sbar.add("item", "widgets.reviews.spacer", { position = POS, width = 4, drawing = false })

local function open_in_browser(url)
	sbar.exec("open -a '" .. BROWSER .. "' '" .. url .. "'")
end

local function hide_details()
	bracket:set({ popup = { drawing = false } })
end
local hide = popup_manager.register(hide_details)

-- Wider than popup_style's default for PR titles. ROW_CHARS is how many characters of the monospace popup font fit
-- across a row (measured on screen); the font and width scale together, so it holds at any display scale.
local width = 420
local ROW_CHARS = 46

local function section(title, query, empty_text, label_share)
	local s = { rows = {}, urls = {}, empty_text = empty_text }
	local header = style.header(bracket.name, "\u{F407}", title)
	header:set({ width = width })
	header:subscribe("mouse.clicked", function()
		open_in_browser("https://github.com/pulls?q=" .. query:gsub(" ", "+"))
		hide_details()
	end)
	for i = 1, MAX_ROWS do
		s.rows[i] = style.row(bracket.name, "", "")
		s.rows[i]:set({
			drawing = false,
			icon = { width = width * (1 - label_share) },
			label = { width = width * label_share },
		})
		s.rows[i]:subscribe("mouse.clicked", function()
			if s.urls[i] then
				open_in_browser(s.urls[i])
				hide_details()
			end
		end)
	end
	return s
end

local requested = section("Review requests", REQUESTED, "Nothing waiting on you", 0.16)
local mine = section("My PRs", MINE, "No open PRs", 0.32)

local function age(seconds)
	if seconds < 3600 then
		return string.format("%dm", math.max(1, seconds // 60))
	elseif seconds < 86400 then
		return string.format("%dh", seconds // 3600)
	end
	return string.format("%dd", seconds // 86400)
end

local function age_color(seconds)
	if seconds >= 86400 then
		return colors.red
	elseif seconds >= 4 * 3600 then
		return colors.yellow
	end
	return style.value_color
end

-- Leaves a two-character gap before the right-aligned label, which grows from the row's right edge.
local function fit(title, label)
	local room = ROW_CHARS - (utf8.len(label) or #label) - 2
	if (utf8.len(title) or #title) <= room then
		return title
	end
	return title:sub(1, (utf8.offset(title, room) or room + 1) - 1) .. "…"
end

local function fill(s, entries)
	for i = 1, MAX_ROWS do
		local e = entries[i]
		s.urls[i] = e and e.url
		if e then
			s.rows[i]:set({
				drawing = true,
				icon = { string = fit(e.title, e.label), color = style.label_color },
				label = { string = e.label, color = e.color },
			})
		else
			s.rows[i]:set({ drawing = false })
		end
	end
	if #entries == 0 then
		s.rows[1]:set({
			drawing = true,
			icon = { string = s.empty_text, color = style.label_color },
			label = { string = "" },
		})
	end
end

local function render(out)
	local total = type(out) == "string" and tonumber(out:match("^total\t(%d+)"))
	if not total then
		reviews:set({ label = { string = "—", color = colors.with_alpha(colors.text, 0.3) } })
		return
	end
	reviews:set({ label = {
		string = tostring(total),
		color = total > 0 and colors.yellow or colors.chrome.label,
	} })

	local waiting, own = {}, {}
	for line in out:gmatch("[^\n]+") do
		local waited, url, title = line:match("^R\t(%d+)\t([^\t]+)\t(.*)$")
		if waited then
			local seconds = tonumber(waited)
			table.insert(waiting, { url = url, title = title, label = age(seconds), color = age_color(seconds) })
		end
		local state, opened, own_url, own_title = line:match("^M\t(%a+)\t(%d+)\t([^\t]+)\t(.*)$")
		if state then
			table.insert(own, {
				url = own_url,
				title = own_title,
				label = state .. " · " .. age(tonumber(opened)),
				color = ({ draft = style.label_color, approved = colors.green })[state] or style.value_color,
			})
		end
	end
	fill(requested, waiting)
	fill(mine, own)
end

local function refresh()
	if is_work then
		sbar.exec(FETCH, render)
	end
end

reviews:subscribe({ "routine", "forced", "system_woke" }, refresh)

reviews:subscribe("mouse.clicked", function()
	if bracket:query().popup.drawing == "off" then
		popup_manager.close_others(hide)
		refresh()
		bracket:set({ popup = { drawing = true } })
	else
		hide_details()
	end
end)
reviews:subscribe("mouse.exited.global", hide_details)

sbar.exec(ENV_CHECK, function(out)
	if type(out) ~= "string" or not out:match("^work") then
		return
	end
	is_work = true
	lead:set({ drawing = true })
	reviews:set({ drawing = true })
	spacer:set({ drawing = POS == "left" })
	refresh()
end)
