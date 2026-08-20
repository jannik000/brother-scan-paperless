#!/bin/sh
# Builds the brscan image and pushes it to ghcr.io, tagged with the current
# git commit. Does NOT touch the floating `:latest` tag - that only moves
# via scripts/promote-image.sh, after the image has passed the dev-VM
# smoke test (see deploy/dev-vm/smoke-test.sh).
#
# The proprietary Brother .deb is never published anywhere; you provide
# your own copy, same as for a normal `docker build`. The image is pushed
# to a *private* ghcr.io package for the same reason - it bakes in that
# proprietary driver.
#
# Requires `docker login ghcr.io` to have been run once beforehand.
#
# Usage: scripts/push-image.sh [BRSCAN_DEB]
set -e

cd "$(dirname "$0")/.."

REGISTRY_IMAGE="ghcr.io/jannik000/brother-scan-paperless"
BRSCAN_DEB="${1:-brscan4-0.4.11-1.amd64.deb}"
REV="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

if [ ! -f "$BRSCAN_DEB" ]; then
    echo "Error: $BRSCAN_DEB not found next to the Dockerfile." >&2
    echo "Download it from Brother's site first (see README)." >&2
    exit 1
fi

echo "Building sdist..."
python3 setup.py build sdist

echo "Building image $REGISTRY_IMAGE:$REV (build arg BRSCAN_DEB=$BRSCAN_DEB)..."
docker build --platform linux/amd64 --build-arg BRSCAN_DEB="$BRSCAN_DEB" \
    -t "$REGISTRY_IMAGE:$REV" .

echo "Pushing $REGISTRY_IMAGE:$REV..."
docker push "$REGISTRY_IMAGE:$REV"

echo
echo "Done: pushed $REGISTRY_IMAGE:$REV (floating :latest untouched)."
echo "Next: deploy/dev-vm/smoke-test.sh $REV"
echo "Then, only if that passes: scripts/promote-image.sh $REV"
