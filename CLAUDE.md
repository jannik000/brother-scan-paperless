# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A daemon (`brscand`) that replaces Brother's proprietary `brscan-skey` helper. It registers
"scan to" menu entries on a Brother network scanner's control panel over SNMP, listens for the
UDP notification the scanner sends when a user presses a scan button, and runs `scanimage` +
`pdfunite`/ImageMagick to turn the scan into a PDF. This fork's specific purpose is scanning
straight into a Paperless-ngx consume directory, with output ownership (`PUID`/`PGID`) and ADF
page-ordering fixed up for that use case.

## Commands

```sh
# Install (editable, with dev deps)
pip install -r requirements-dev.txt -e .

# Lint (only real bugs: syntax errors, unused/undefined names — see pyproject.toml)
ruff check .

# Test all
pytest

# Test one file / one case
pytest tests/test_scanto.py
pytest tests/test_scanto.py::test_add_scan_options_appends_known_options

# Build the sdist that the Dockerfile installs into the image
python3 setup.py build sdist

# Build the Docker image (requires the proprietary Brother .deb next to the
# Dockerfile — not committed to this repo, must be downloaded from Brother)
docker build --build-arg BRSCAN_DEB="brscan4-0.4.11-1.amd64.deb" -t brscan .

# Build + export an image as a tar.gz for targets with no build tooling (e.g. a NAS)
scripts/build-image.sh brscan4-0.4.11-1.amd64.deb

# Build + push an image to the private ghcr.io registry, tagged with the
# current commit (does not move the floating :latest tag - see below)
scripts/push-image.sh brscan4-0.4.11-1.amd64.deb

# Smoke-test a pushed tag in an isolated stack before promoting it
deploy/dev-vm/smoke-test.sh <tag>

# Promote a smoke-tested tag to :latest (pure registry retag, no rebuild)
scripts/promote-image.sh <tag>
```

CI (`.github/workflows/*.yml`) runs `ruff check .` + `pytest`, and separately does a full Docker
build using a fake placeholder `brscan4` .deb (dpkg package with no real driver payload), since the
real one can't be fetched automatically.

Because of that same constraint, the real image is never built in CI: `scripts/push-image.sh`
builds and pushes it from wherever the real `.deb` lives (a private ghcr.io package, since the
image bakes in Brother's proprietary driver). The floating `:latest` tag only moves via
`scripts/promote-image.sh`, after `deploy/dev-vm/smoke-test.sh` has passed for that tag - never
automatically on push. `deploy/dev-vm/` is a boot-only smoke test (unreachable dummy
`SCANNER_IP`): a real scan-button test would fight whatever's currently deployed for the
scanner's attention, so that stays a manual, deliberate step.

## Architecture

Runtime is `brscand` (`brscan/brscand.py`), invoked as `brscand [-c CONFIG] BIND_ADDR SCANNER_ADDR`
(see `run.sh` for how the Docker image drives it). It resolves hostnames, loads the YAML config
(`brother-scan.yaml`, see `brother-scan.yaml.sample`), then starts two threads that run for the
life of the process:

- **`snmp.py`** (`snmp.launch` → `_launch`, asyncio via `pysnmp` v1arch): every 60s, SNMP-sets the
  Brother `SCAN_TO_OID` on the scanner once per `(func, user)` entry in the config's `menu` map.
  This is what makes the entries show up as buttons on the scanner's physical control panel; each
  entry advertises this daemon's own `(advertise_addr, advertise_port)` as the destination to
  notify when pressed.
- **`listen.py`** (`listen.launch`): a UDP server on `bind_addr:bind_port` (default port `54925`)
  that receives the notification the scanner fires when someone presses one of those buttons,
  parses Brother's `TYPE=BR;USER="...";FUNC=...;...` wire format (`parse_notification`), matches
  `FUNC`/`USER` back against the same config `menu` map, and calls `scanto.scanto()` with the
  matching options. A scan failure is caught and logged so the listener stays alive for the next
  notification.
- **`scanto.py`** (`scanto()`): shells out to `scanimage` (single page, or `--batch` for ADF —
  `scanadf` is no longer packaged in current Debian, so `scanimage --batch` replaces it and writes
  one PNM per page), converts each PNM to PDF via `wand`/ImageMagick, and for ADF jobs concatenates
  pages with `pdfunite`. ADF pages are explicitly sorted by mtime before concatenation, since
  `scanimage --batch` filenames don't glob back in scan order. The final PDF is moved from `/tmp`
  into the configured output dir and `chown`ed to `PUID`:`PGID` (env vars, default `1000:1000`) so
  it matches the ownership Paperless expects on its consume dir.

Config shape (`brother-scan.yaml`): a `menu` map keyed by function (`file`, `email`, ...), then by
button/user label, then scan options (`dir`, `resolution`, `width`, `height`, `adf`, plus anything
in `scanto.scan_options` — these map directly to `scanimage` CLI flags).

Docker image (`Dockerfile`): installs `sane-utils`/`poppler-utils`/`libusb-0.1-4`/`imagemagick`,
installs the user-supplied proprietary Brother `.deb` (`BRSCAN_DEB` build arg), symlinks
`libsane-brother*` into `/usr/lib/sane` (Brother's installer puts them in `/usr/lib64/sane`, which
Debian's SANE doesn't scan), installs the `brscan` sdist built by `setup.py`, and patches
ImageMagick's policy to allow the PDF coder (needed by `wand` in `scanto.py`).
