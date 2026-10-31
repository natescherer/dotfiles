## Working style

- Push back on short-sighted or flawed proposals directly.
- Never create or modify files under my home folder without asking first.
- Put temporary files only in the scratchpad directory your tool provides or,
  without one, the platform's user temp location: `$env:TEMP` on Windows, and
  `$TMPDIR` or `/tmp` on macOS and Linux. These locations are exempt from the
  home folder rule above. Create scratch directories nowhere else, including
  drive roots, the home folder, and repositories.
- Confirm the platform and shell before writing a path. Outside Git Bash and
  MSYS, Windows resolves POSIX paths against the current drive: `/tmp` becomes
  `C:\tmp`, and `/c/foo` becomes `C:\c\foo`.
