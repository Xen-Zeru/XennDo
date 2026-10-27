# Source publication checklist

This checklist concerns the first public GitHub source release. Android binary
signing and store qualification are covered separately in
[RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## Cleanup review — 2026-10-26

- The supplied folder initially had **no `.git` metadata or inspectable Git remote**.
  Files were reviewed as publication candidates using the ignore policy; they
  cannot truthfully be labeled tracked or untracked without an index.
- No repository URL, publisher account or release URL was invented. No
  commit, push, GitHub Release upload or visibility change was performed.
- No project `LICENSE` file exists. The owner must decide the licensing terms;
  no license was selected or added during cleanup. Dependency licenses remain
  available through Flutter's in-app license page.
- Private runtime databases and backup exports are excluded from publication.
  Existing verification copies were preserved outside the project. Machine-local
  SDK/IDE configuration remains local and ignored.
- Required source, tests, migrations/generated database source, `pubspec.lock`,
  `.metadata`, Android resources and the Gradle wrapper are retained.
- The final 147 ignore-policy publication candidates were scanned for credential
  signatures, private keys, personal database/backup exports and literal home
  paths; none were found. This is a working-folder check, not a guarantee about
  unavailable Git history. Full validation results are in [PROGRESS.md](PROGRESS.md).

## Git setup — 2026-10-28

- Owner-supplied repository: [Xen-Zeru/XennDo](https://github.com/Xen-Zeru/XennDo).
- Local Git initialized with branch `main`; commit identity is configured locally.
- `origin` uses `git@github.com:Xen-Zeru/XennDo.git` for SSH transport.
- An HTTPS remote-reference query succeeded and returned no refs: the remote was
  empty at inspection. No existing remote commits were overwritten.
- SSH authentication returned `Permission denied (publickey)`. Remote push and
  upstream verification require working GitHub SSH authentication.
- Publication authorization is for source only. No APK upload, GitHub Release,
  visibility change, new license or force-push is authorized.

## Before committing and pushing

1. Confirm the project root, branch, identity and intended remote. Check remote
   history again before pushing; preserve any work that appears after inspection.
2. Keep licensing unchanged unless the owner explicitly supplies different terms.
3. Review the exact working-tree and staged changes, including any changes that
   predate this cleanup. Use explicit paths when staging.
4. Inspect ignored files that might already be tracked. Ignore rules do not remove
   existing index entries. For an intentionally private tracked file, remove only
   its index entry with `git rm --cached -- <path>` after review, preserving the
   local file. Do not indiscriminately untrack required generated files.
5. Review the staged candidate set for credentials, signing material, personal
   databases/backups, private screenshots and machine-specific paths.
6. If reconnecting existing history, scan that history separately. It was not
   available here. Revoke/rotate any exposed credentials first; arrange any
   necessary history cleanup with the owner. Do not rewrite history automatically.

Useful read-only review commands once Git metadata is available:

```bash
git status --short --branch
git remote -v
git diff --stat
git diff --cached --stat
git diff --cached --check
git ls-files -ci --exclude-standard
git ls-files --others --exclude-standard
git status --short --ignored
```

## Review the release contents

- Keep source, tests, platform configuration, lockfile and required generated
  source in the release. Keep the Gradle wrapper so its version is reproducible.
- Exclude build caches, SDK paths, IDE user state, logs, environment files,
  keystores, passwords, personal exports/databases and development captures.
- Check asset references and documentation links after removals.
- Run the README formatting, analysis, test and debug-build commands.
- Inspect any binary separately before choosing to distribute it. A locally
  generated debug APK is development-signed; a release APK without owner signing
  is unsigned and cannot be installed. No hosted release is assumed here.

A source push does not authorize binary distribution or a visibility change.
