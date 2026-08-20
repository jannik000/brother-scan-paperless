#!/bin/sh
# Boots deploy/dev-vm/docker-compose.yml against the given image tag and
# checks that the container starts cleanly: SANE registration doesn't kill
# the process, the SNMP loop and UDP listener both come up, nothing crashes
# in the first few seconds.
#
# Deliberately does NOT test scanning against a real device - SCANNER_IP is
# unreachable on purpose (see docker-compose.yml): a real test would fight
# the production container on the NAS for the scanner's attention.
#
# Usage: deploy/dev-vm/smoke-test.sh <image-tag>
set -e

cd "$(dirname "$0")"
mkdir -p output

IMAGE_TAG="${1:?Usage: smoke-test.sh <image-tag>}"
export IMAGE_TAG

cleanup() {
    docker compose logs
    docker compose down
}
trap cleanup EXIT

docker compose pull
docker compose up -d

echo "Waiting 15s for startup..."
sleep 15

if [ -z "$(docker compose ps -q --status running)" ]; then
    echo "FAIL: container exited during startup" >&2
    exit 1
fi

LOGS="$(docker compose logs)"

if echo "$LOGS" | grep -q "Traceback (most recent call last)"; then
    echo "FAIL: unhandled exception in startup logs" >&2
    exit 1
fi

if ! echo "$LOGS" | grep -q "Listening on"; then
    echo "FAIL: UDP listener never started" >&2
    exit 1
fi

echo "OK: $IMAGE_TAG started cleanly, UDP listener is up."
