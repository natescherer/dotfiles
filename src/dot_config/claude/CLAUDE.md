<!-- WARNING: This file is chezmoi-managed and should not be manually edited! -->
# CLAUDE.md

## Where to save durable knowledge

Before saving something you learn (workflow rules, gotchas, established
patterns -- not one-off task context) to persistent memory, ask which of
these it belongs in, rather than guessing:

- **Private local memory** -- tied to one project, not shared with the team
  or other tools.
- **The project's `AGENTS.md`** -- version-controlled, shared with the team
  and interoperable across coding agents; for conventions specific to that
  project. If a `CLAUDE.md` file doesn't exist yet, make one that imports
  `AGENTS.md` as well.
- **This file** -- applies to every project you personally work in, but
  private to you and invisible to teammates or other tools.

## Git workflow

- Default to a feature branch + PR for any change -- do not commit directly to
  `main` unless explicitly re-authorized for a specific batch.
- When working through more than one independent fix/feature, commit **one
  logical change at a time**: make the change, verify it for real (render,
  lint, test -- not assumption), stage it, show the diff, propose a commit
  message, and wait for explicit approval before running `git commit`. Don't
  bundle unrelated fixes into one commit, even if it's faster -- it's fine to
  bundle a fix with file(s) it's obviously coupled to (e.g. a new file plus
  the config change needed to lint it).
- Proposing a commit message inside a longer summary is **not** approval to
  commit. Print the full proposed message as its own block (e.g. a code
  fence), then wait for a distinct yes -- don't infer approval from the
  absence of an objection to a summary that already contains the message.
- Push the branch immediately after every `git commit` -- no separate
  confirmation needed for the push itself. Opening the PR is still a separate
  step, done only when asked (the usual pattern is the human opens/merges the
  PR themselves).
- After a commit+push, if there's no more queued work on that branch, switch
  back to `main` (and `git pull`) rather than leaving the session sitting on a
  finished feature branch.
