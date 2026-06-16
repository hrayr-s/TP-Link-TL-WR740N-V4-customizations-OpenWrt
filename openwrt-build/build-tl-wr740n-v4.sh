#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_CONFIG="${PROFILE_CONFIG:-${REPO_ROOT}/profiles/tl-wr740n-v4-vpn-wds.env}"
export PROFILE_CONFIG

exec "${REPO_ROOT}/scripts/build-openwrt-image.sh"
