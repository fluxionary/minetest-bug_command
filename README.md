# bug_command

adds a command that submits a bug report to a github repo.

other git hosts might be added at a later date.

### for server operators:

you must add the mod to `secure.http_mods`, and supply two additional settings:

#### `bug_command:github_repo`

e.g. `bug_command:github_repo = fluxionary/fluxtest` will add issues to https://github.com/fluxionary/minetest-fluxtest/issues

#### `bug_command:github_token`

see the following for how to get one:

https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token#creating-a-fine-grained-personal-access-token

### usage

as a command line argument:

```
/bug blah blah blah
```
