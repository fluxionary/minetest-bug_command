local private_state = ...
local http = private_state.http

local f = string.format
local F = minetest.formspec_escape
local S = bug_command.S
local function FS(...)
	return F(S(...))
end

local token = bug_command.settings.github_token
local repo = bug_command.settings.github_repo

local selected_index_by_player_name = {}
local id_by_index_by_player_name = {}
local current_page_by_player_name = {}

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	selected_index_by_player_name[player_name] = nil
	id_by_index_by_player_name[player_name] = nil
end)

--[[
https://docs.github.com/en/rest/issues/issues#create-an-issue
]]
local function build_bugs_request(player_name)
	local param_table = {
		page = tostring(current_page_by_player_name[player_name] or 1),
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

local function build_bugs_formspec(data, player_name)
	local parts = {
		"size[8.5,10;]",
		f("button[6,0.95;2.5,0.5;details;%s]", FS("details")),
		f("button[6,1.70;2.5,0.5;next_page;%s]", FS("next page")),
		f("button[6,2.45;2.5,0.5;previous_page;%s]", FS("previous page")),
		"tablecolumns[color;text;text]",
		f("table[0,0.7;5.75,8.35;bugs;#999,%s,%s", FS("id"), FS("title")),
	}
	local id_by_index = {}
	for index, issue in ipairs(data) do
		local number = issue.number
		local title = issue.title
		local color
		if issue.state == "open" then
			color = "#0F0"
		elseif issue.state == "closed" then
			color = "#80F"
		else
			color = "#F00"
		end
		table.insert(parts, f(",%s,%s,%s", color, F(number), F(title)))
		id_by_index[index + 1] = number
	end
	table.insert(parts, "]")

	id_by_index_by_player_name[player_name] = id_by_index
	return table.concat(parts, "")
end

local function make_show_list_callback(player_name)
	return function(result)
		if result.completed and result.code == 200 then
			local data = minetest.parse_json(result.data)
			if data then
				local form = build_bugs_formspec(data, player_name)
				minetest.show_formspec(player_name, "bug_command:list", form)
			end
		end
	end
end

local function build_details_request(id)
	return {
		url = f("https://api.github.com/repos/%s/issues/%s", repo, id),
		timeout = 10,
		method = "GET",
		extra_headers = {
			"Accept: application/vnd.github+json",
			f("Authorization: Bearer %s", token),
			"X-GitHub-Api-Version: 2022-11-28",
		},
	}
end

local function build_details_formspec(data)
	local parts = {
		"size[8,9]",
		"box[0,0;7,1.9;#466432]",
		"button[7.25,0.15;0.75,0.5;back;X]",
		f("label[0.2,0.1;%s: %s]", S("id"), data.number),
		f("label[0.2,0.5;%s: %s]", S("state"), data.state),
		f("label[0.2,0.9;%s: %s]", S("created"), data.created_at),
		f("label[0,2.1;%s: %s]", S("title"), data.title),
		f("textarea[0.25,2.6;8,7.0;;;%s]", data.body),
	}

	return table.concat(parts, "")
end

local function make_show_details_callback(player_name)
	return function(result)
		if result.completed and result.code == 200 then
			local data = minetest.parse_json(result.data)
			if data then
				local form = build_details_formspec(data, player_name)
				minetest.show_formspec(player_name, "bug_command:details", form)
			end
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
	func = function(player_name, param)
		http.fetch(build_bugs_request(player_name), make_show_list_callback(player_name))
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not formname:match("^bug_command:") then
		return
	end
	local player_name = player:get_player_name()
	if fields.bugs then
		local index = fields.bugs:match("^CHG:(%d+):")
		selected_index_by_player_name[player_name] = tonumber(index)
	end
	if fields.details then
		local index = selected_index_by_player_name[player_name]
		if index then
			local id = (id_by_index_by_player_name[player_name] or {})[index]
			if id then
				http.fetch(build_details_request(id), make_show_details_callback(player_name))
			end
		end
	elseif fields.next_page then
		current_page_by_player_name[player_name] = (current_page_by_player_name[player_name] or 1) + 1
		http.fetch(build_bugs_request(player_name), make_show_list_callback(player_name))
	elseif fields.previous_page then
		current_page_by_player_name[player_name] = math.max(1, (current_page_by_player_name[player_name] or 1) - 1)
		http.fetch(build_bugs_request(player_name), make_show_list_callback(player_name))
	elseif fields.back then
		http.fetch(build_bugs_request(player_name), make_show_list_callback(player_name))
	end
end)
