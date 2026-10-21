# Server v1.0.6

Task rows now offer Done, Skipped, Failed and Clear actions. Numeric tasks can
be skipped or failed without entering a measurement; measured zero remains a
measurement. Notes and individual check-in slots survive state changes.

The web interface improves click targets, keyboard access, narrow screen
layouts, large text, safe areas, dark theme contrast and reduced motion.
History, charts, scores, streaks and CSV exports distinguish numeric failures.
Use iOS 1.0 (20) for matching numeric state controls and interpretation.

The build dependencies also include patched Vite 8.2.4 and source-map-js 1.2.2.
The server uses Go 1.26.10, including the latest standard-library security fixes,
and golang.org/x/crypto 0.56.0.

## Updating

Update the Docker container while keeping its data volume and permanent secret.
Existing sessions, device tokens and stored habit data remain valid. The setup
helper pins 1.0.6 for new installations. The running server is not automatically
restarted by image publication.

## Validation

- Go 1.26.10: all 11 packages pass uncached; store tests complete in 142.814 seconds.
  Go vet, staticcheck, module verification and tidy checks pass.
- Govulncheck finds zero affected application code or imported packages. One
  advisory remains in unused OpenPGP code in the required crypto module.
- Web: 358 unit tests, 23 hostile bundle cases, strict Svelte/TypeScript and build
  pass; npm audit reports zero vulnerabilities.
- The exact published digest passes all three browser tests, including seven
  screen widths from 320 to 1600 pixels, light/dark contrast, direct states,
  numeric history, reload, multiple tabs and offline edits.
- The exact published digest passes fresh setup, enrollment, native two-way
  boolean/numeric state sync, offline catch-up, restart, backup, restore and
  re-enrollment. A separate linux/amd64 container passes its startup healthcheck
  with a read-only root, no capabilities and no network.

## Publication

Published 21 October 2026 from `5304fa9e2b839df36343ef20c72a00cb56865c95`,
annotated tag `v1.0.6`. Tags `1.0.6`, `1.0`, `1` and `latest` share this digest:

`ghcr.io/darkishlocket10/yabits-server@sha256:7db67a7e4d0c6720b88d68eee47dd772742c21d2af309a840c7203d8799166d2`

Anonymous registry verification confirms both Linux architectures, version,
source revision, uid:gid 99:100, SPDX SBOM and SLSA provenance for each architecture.
Local BuildKit produced this release without hosted Actions minutes or a
GitHub workflow OIDC signature. The running Unraid server was not restarted.
