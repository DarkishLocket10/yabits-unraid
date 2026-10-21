# Server v1.0.7

The companion web app now has daily notes and optional failure explanations for
both checklist and numeric tasks, matching iOS 1.0 (21).

Choose Add a note or Edit today's note on a task, Today's note in its details,
or edit a date in History. Every editor captures the task and civil date before
loading. Saving after midnight still updates the selected day. A note-only edit
preserves a newer check-in, source, slots and completion timestamp. State-only
history edits preserve newer notes. Conflicting edits keep the draft for review.

After a new Failed check-in is saved, an optional reason dialog opens. Not now
keeps the failed check-in. Repeating Failed and saving a numeric measurement do
not trigger the prompt. History also offers an optional reason for failures.

Settings and the welcome flow include Enable daily notes and Ask why a task
failed. These are browser/account-local preferences. Disabling daily notes hides
the editors and prompts without deleting existing notes; the prompt preference
is remembered independently. Existing browser preferences migrate automatically.

Notes use the existing compact monthly sync payload. Opening a note reads only
the selected task and entry year, without scanning history. New or edited notes
are limited to 4,096 UTF-8 bytes. Existing longer notes remain intact when
unchanged, and no-op edits do not queue sync writes. No server protocol or schema
change is required; Go continues to store opaque typed fields.

## Updating

Pull the updated Docker image and recreate the container while keeping the same
`/data` volume and permanent secret. Sessions, device enrollment and existing
notes remain valid. Publishing an image does not restart the running container.
Use iOS 1.0 (21) for native daily notes and failure prompt controls.

## Validation

- 366 web unit tests, 23 hostile bundle cases, strict Svelte/TypeScript checks and
  production build pass. npm audit reports zero vulnerabilities.
- Four production-browser flows pass, including numeric and boolean failure
  prompts, notes reload, distinct dates, stale drafts across tabs, offline saves,
  preference persistence, welcome controls, 320px dialogs, accessibility and
  seven screen widths up to 1600px.
- All 11 Go packages pass uncached (store: 130.177 seconds). Go vet, staticcheck,
  module verification and tidy checks pass. Govulncheck finds zero affected
  application code or imported packages; one advisory is in unused OpenPGP code.
- Fresh Docker setup, enrollment, restart, native boolean/numeric two-way sync,
  note sync, offline catch-up, backup, restore and re-enrollment pass.
- The exact published digest passes all four browser tests (18.2 seconds) and
  the fresh setup/native sync/backup/restore drill. Light/dark notes dialogs pass
  accessibility and narrow-screen checks. Anonymous registry checks confirm
  both architectures, source/version labels, uid:gid 99:100, SPDX SBOM and SLSA
  provenance. The release used local BuildKit, with no hosted Actions minutes
  or workflow OIDC signature. The running Unraid server was not restarted.

## Publication

Published 21 October 2026 from `0651fd34c5fe0e690f7113be30ab51673b020fe1`,
annotated tag `v1.0.7`. Versioned image:

`ghcr.io/darkishlocket10/yabits-server@sha256:361625ed396ed2e5f5bcb60cadc4ac88ebc05aadd8fb659eb93d84d22d651f57`

The separate linux/amd64 image also passes its healthcheck with a read-only root,
no capabilities and no network. Tags `1.0.7`, `1.0`, `1` and `latest` share this digest.
Anonymous registry verification confirms every tag and both architectures.
