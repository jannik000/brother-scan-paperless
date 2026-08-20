#!/bin/sh
# Promotes an already-pushed, already-smoke-tested image tag to the
# floating `:latest` tag that the NAS deploy pulls - a pure registry
# retag via `docker buildx imagetools`, no rebuild.
#
# Run this only after deploy/dev-vm/smoke-test.sh has passed for the given
# tag: `:latest` is what production pulls, so this is the actual
# release/go-live moment, never an automatic side effect of pushing.
#
# Usage: scripts/promote-image.sh <tag>   (the short sha push-image.sh printed)
set -e

REGISTRY_IMAGE="ghcr.io/jannik000/brother-scan-paperless"
TAG="${1:?Usage: promote-image.sh <tag>}"

echo "Promoting $REGISTRY_IMAGE:$TAG -> $REGISTRY_IMAGE:latest..."
docker buildx imagetools create -t "$REGISTRY_IMAGE:latest" "$REGISTRY_IMAGE:$TAG"

echo "Done. $REGISTRY_IMAGE:latest now points at $TAG."
