## Git workflow

- Default to a feature branch + PR for any change; do not commit directly to
  `main` unless explicitly re-authorized for a specific batch.
- When working through more than one independent fix/feature, commit **one
  logical change at a time**: make the change, verify it for real (render,
  lint, and test, not assumption), stage it, show the diff, propose a commit
  message, and wait for explicit approval before running `git commit`. Don't
  bundle unrelated fixes into one commit, even if it's faster. It's fine to
  bundle a fix with file(s) it's obviously coupled to (e.g. a new file plus
  the config change needed to lint it).
- When separate fixes will each be reviewed/merged independently (not as a
  stacked series), give each one its own branch off `main` rather than
  stacking multiple commits on one branch so they can land in any order
  without one PR depending on another. Before creating each new branch,
  `git checkout main && git pull` first, since an earlier branch in the same
  batch may already have been merged.
- Proposing a commit message inside a longer summary is **not** approval to
  commit. Print the full proposed message as its own block (e.g. a code
  fence), then wait for a distinct yes, don't infer approval from the
  absence of an objection to a summary that already contains the message.
- Push the branch immediately after every `git commit`. No separate
  confirmation needed for the push itself. Opening the PR is still a separate
  step, done only when asked (the usual pattern is the human opens/merges the
  PR themselves).
- After a commit+push, if there's no more queued work on that branch, switch
  back to `main` (and `git pull`) rather than leaving the session sitting on a
  finished feature branch.
- Never add a `Co-Authored-By` trailer (or any other AI-attribution line) to
  commit messages; author commits as mine alone.
- Default a new git repository's initial branch to `main`, never `master`.
- Commit messages should follow Conventional Commits
  (commitlint/config-conventional) by default. A project's own AGENTS.md/CLAUDE.md
  convention takes precedence when it specifies one.
- Never create or modify files under my home folder without asking first.
