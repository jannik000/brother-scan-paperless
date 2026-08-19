#!/bin/sh
# Builds the brscan image and exports it as a .tar.gz, for deploying to a
# target (e.g. a NAS) that only has Docker and no Python/build tooling.
#
# The proprietary Brother .deb is never published anywhere; you provide your
# own copy, same as for a normal `docker build`.
#
# Usage: scripts/build-image.sh [BRSCAN_DEB] [OUTPUT_FILE]
set -e

cd "$(dirname "$0")/.."

BRSCAN_DEB="${1:-brscan4-0.4.11-1.amd64.deb}"
REV="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
OUTPUT_FILE="${2:-brscan-image-$REV.tar.gz}"

if [ ! -f "$BRSCAN_DEB" ]; then
    echo "Error: $BRSCAN_DEB not found next to the Dockerfile." >&2
    echo "Download it from Brother's site first (see README)." >&2
    exit 1
fi

echo "Building sdist..."
python3 setup.py build sdist

echo "Building image brscan:$REV (build arg BRSCAN_DEB=$BRSCAN_DEB)..."
docker build --build-arg BRSCAN_DEB="$BRSCAN_DEB" -t brscan:"$REV" -t brscan:latest .

echo "Exporting to $OUTPUT_FILE..."
docker save brscan:latest | gzip > "$OUTPUT_FILE"

echo "Done: $OUTPUT_FILE (image tagged brscan:$REV and brscan:latest)"
