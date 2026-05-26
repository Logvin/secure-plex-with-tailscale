#!/usr/bin/env bash
# setup.sh - one-shot deployment of the secure Plex stack
#
# Usage: ./setup.sh
#
# Prereqs:
#   - Docker + Docker Compose installed
#   - .env file populated (see .env.example)
#   - acl.hujson uploaded to your tailnet (or GitOps wired up)
#
# What this script does:
#   TODO

set -euo pipefail

# TODO: implement
# Suggested steps:
#   1. Verify .env exists and has TS_AUTHKEY set
#   2. Verify docker + docker compose are available
#   3. Pull images
#   4. Bring up the stack
#   5. Wait for ts-subnet-router to authenticate
#   6. Print a short status summary (tailscale status from the router)

echo "Not yet implemented."
exit 1
