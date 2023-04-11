local private_state = ...
local http = private_state.http

local f = string.format
local S = bug_command.S

local token = bug_command.settings.github_token
local repo = bug_command.settings.github_repo

--[[
https://docs.github.com/en/rest/issues/issues#create-an-issue
]]
local function build_report_request(page)
	local param_table = {
		page = tostring(page or 1),
	}
	local params = {}
	for key, value in pairs(param_table) do
		table.insert(params, f("%s=%s", futil.urlencode(key), futil.urlencode(value)))
	end
	params = table.concat(params, "&")

	return {
		url = f("https://api.github.com/repos/%s/issues?%s", repo, params),
		timeout = 10,
		method = "GET",
		extra_headers = {
			"Accept: application/vnd.github+json",
			f("Authorization: Bearer %s", token),
			"X-GitHub-Api-Version: 2022-11-28",
		},
	}
end

local function build_formspec(data)
	local parts = {
		"size[8.5,10;]",
		f("button[6,0.95;2.5,0.5;details;%s]", S("details")),
		"tablecolumns[color;text;text]",
		f("table[0,0.7;5.75,8.35;inbox;#999,%s,%s", S("id"), S("title")),
	}
	for _, issue in ipairs(data) do
		local id = issue.id
		local title = issue.title
		local color
		if issue.state == "open" then
			color = "#0F0"
		elseif issue.state == "closed" then
			color = "#80F"
		else
			color = "#F00"
		end
		table.insert(parts, f(",%s,%s,%s", color, id, title))
	end
	table.insert(parts, "]")

	return table.concat(parts, "")
end

local function make_show_list_callback(name)
	return function(result)
		if result.completed and result.code == 200 then
			local data = minetest.parse_json(result.data)
			local form = build_formspec(data)
			minetest.show_formspec(name, "bug_command:list", form)
		end
	end
end

local privs
if bug_command.settings.required_privilege then
	privs = { [bug_command.settings.required_privilege] = true }
end

minetest.register_chatcommand("bugs", {
	description = S("read bug reports"),
	privs = privs,
	func = function(name, param)
		http.fetch(build_report_request(), make_show_list_callback(name))
	end,
})
