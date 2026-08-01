# CLAUDE.md

Instructions for Claude Code when working in this repository.

- Always pass `--use-builtin-diff` when running `chezmoi diff`. Without it, chezmoi
  shells out to the configured external diff tool (`code --wait --diff`), which opens
  interactive VS Code windows and blocks waiting for them to be closed.
