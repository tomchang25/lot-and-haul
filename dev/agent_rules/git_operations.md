# Git Operations — Read-Only

Agents must NEVER run git commands that mutate repo state: no `git add`, `commit`, `restore`, `reset`, `stash`, `checkout`, `rm`, or `mv`. The sandbox mount desyncs on `.git/` (phantom `index.lock`, EEXIST on files that don't exist), so staging attempts fail unpredictably and waste tokens.

## Rules

- Read-only git is fine and reliable: `status`, `diff`, `log`, `show`, `ls-files`, `cat-file`, `check-ignore`.
- When work is done, at most **suggest a commit message** (format per `dev/skills/conventional_commits.md`). The user stages and commits themselves.
- Never retry a failed git mutation "one more way" — stop at the first failure and hand off to the user.
