local http = minetest.request_http_api()

if not http then
	error("bug_command requires access to the http api; please add it to secure.http_mods in minetest.conf")
end

futil.check_version({ year = 2023, month = 4, day = 11 })

bug_command = fmod.create(nil, {
	http = http,
})

if not bug_command.settings.github_token then
	error("github token required; set bug_command:github_token in minetest.conf")
end

if not bug_command.settings.github_repo then
	error("github repo required; set bug_command:github_repo in minetest.conf")
end

bug_command.dofile("bug_command")
bug_command.dofile("bugs_command")
