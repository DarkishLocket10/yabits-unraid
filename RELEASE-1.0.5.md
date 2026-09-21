# Server v1.0.5

A completed backup restore can now start normally. Earlier releases discarded
the old setup token during restore, then incorrectly required it at startup.
The fix accepts a completed restore's durable epoch and completion markers;
unclaimed, incomplete or inconsistent authentication state still cannot serve.

The web build also updates its transitive `devalue` dependency to 5.9.4 for GHSA-9rgm-9g3h-6x36.

The Docker setup helper now pins 1.0.5. The setup and restore guides include
account recovery, fresh device enrollment and a two-way sync check.

## Updating

Take an offline backup using the server command, then update the container while
keeping the same data volume and permanent secret key. No database migration or
fresh installation is required. Existing sessions and app tokens are unchanged
by this update. Restoring a backup still revokes them and requires signing in
and enrolling each device again. Upgrade from 1.0.4 before attempting a restore.

## Validation

- Full uncached Go suite: all 11 packages pass (store: 120.552 seconds).
- Go vet, staticcheck, module verification and tidy checks pass. Changed restore
  paths pass under the race detector. Govulncheck finds no reachable or imported-
  package vulnerabilities (four advisories only in unused required-module code).
- Web: 352 unit tests, 23 hostile bundle cases, strict Svelte/TypeScript and build pass.
- Production browser E2E: both tests pass, including reload, multiple tabs and
  offline edits. Clean npm install and audit report zero vulnerabilities.
- Fresh disposable Docker installation: setup, enrollment, restart, native
  done/skip/failed/clear sync, offline catch-up, backup, restore, restart, sign-in
  and fresh native enrollment pass. The original habit survives the restore.
- Regression tests cover completed validated and disaster recovery, rejection
  of incomplete recovery, and the ordinary claimed-instance setup-token rule.

## Publication

Published 21 September 2026 from `741ef24d3dc7b5cd1e33c4b8997fafdf2abfdc3c`,
annotated tag `v1.0.5`. Tags `1.0.5`, `1.0`, `1` and `latest` share this digest:

`ghcr.io/darkishlocket10/yabits-server@sha256:ad436fd99bbf8711d52a97c5f03facb10a26d707e0718d390585e4c3edb520da`

Anonymous pulls verify both Linux architectures, version, source revision,
uid:gid 99:100, SPDX SBOM and SLSA provenance. The exact published digest passes
the fresh Docker setup, backup/restore, re-enrollment and native sync drill.
Local BuildKit produced this release without hosted Actions minutes or a
GitHub workflow OIDC signature. The running Unraid server was not restarted.

