local private_state = ...
local http = private_state.http

local f = string.format
local S = bug_command.S

local token = bug_command.settings.github_token
local repo = bug_command.settings.github_repo

local function build_report_message(name, param)
	local parts = param:split("%s+", false, -1, true)
	local title_length = 0
	local title_parts = {}
	for _, part in ipairs(parts) do
		table.insert(title_parts, part)
		title_length = title_length + part:len() + 1
		if title_length > 40 then
			table.insert(title_parts, "...")
			break
		end
	end

	return {
		title = table.concat(title_parts, " "),
		body = f("%s reports: %s", name, param),
	}
end

--[[
https://docs.github.com/en/rest/issues/issues#create-an-issue
]]
local function build_report_request(message)
	return {
		url = f("https://api.github.com/repos/%s/issues", repo),
		timeout = 10,
		method = "POST",
		extra_headers = {
			"Accept: application/vnd.github+json",
			f("Authorization: Bearer %s", token),
			"X-GitHub-Api-Version: 2022-11-28",
		},
		data = minetest.write_json({
			title = message.title,
			body = message.body,
		}),
	}
end

local function make_report_callback(name)
	return function(result)
		if not result.completed then
			return
		end
		if result.code == 201 then
			local response = minetest.parse_json(result.data)
			if response.html_url then
				bug_command.chat_send_player(name, "your bug report was received. @1", response.html_url)
			else
				bug_command.chat_send_player(name, "an error occurred: @1", result.data)
			end
		elseif result.timeout then
			bug_command.chat_send_player(name, "bug submission timed out, please try again.")
		else
			bug_command.chat_send_player(name, "an error occurred: @1", result.data)
		end
	end
end

local privs
if bug_command.settings.required_privilege then
	privs = { [bug_command.settings.required_privilege] = true }
end

minetest.register_chatcommand("bug", {
	params = "<bug report>",
	description = S("submit a bug report"),
	privs = privs,
	func = function(name, param)
		if param:gsub("%s+", "") == "" then
			return false, S("invalid bug report")
		end

		local message = build_report_message(name, param)
		http.fetch(build_report_request(message), make_report_callback(name))
		return true, S("sending bug request...")
	end,
})
