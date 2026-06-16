#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_CONFIG="${PROFILE_CONFIG:-${REPO_ROOT}/profiles/tl-wr740n-v4-vpn-wds.env}"

if [[ "${PROFILE_CONFIG}" != /* ]]; then
  PROFILE_CONFIG="${REPO_ROOT}/${PROFILE_CONFIG}"
fi

if [[ ! -f "${PROFILE_CONFIG}" ]]; then
  echo "Profile config not found: ${PROFILE_CONFIG}" >&2
  exit 2
fi

check_sha256() {
  local expected="$1"
  local path="$2"

  if command -v shasum >/dev/null 2>&1; then
    printf '%s  %s\n' "${expected}" "${path}" | shasum -a 256 -c -
    return
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "${expected}" "${path}" | sha256sum -c -
    return
  fi

  echo "Neither shasum nor sha256sum is available." >&2
  exit 2
}

print_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$@"
    return
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@"
    return
  fi

  echo "Neither shasum nor sha256sum is available." >&2
  exit 2
}

# shellcheck source=/dev/null
source "${PROFILE_CONFIG}"

OPENWRT_RELEASE="${OPENWRT_RELEASE:?missing OPENWRT_RELEASE}"
TARGET_SUBDIR="${TARGET_SUBDIR:?missing TARGET_SUBDIR}"
IMAGEBUILDER_NAME="${IMAGEBUILDER_NAME:?missing IMAGEBUILDER_NAME}"
IMAGEBUILDER_URL="${IMAGEBUILDER_URL:?missing IMAGEBUILDER_URL}"
IMAGEBUILDER_SHA256="${IMAGEBUILDER_SHA256:?missing IMAGEBUILDER_SHA256}"
PROFILE="${PROFILE:?missing PROFILE}"
PACKAGES="${PACKAGES:?missing PACKAGES}"
OUTPUT_TAG="${OUTPUT_TAG:?missing OUTPUT_TAG}"
OVERLAY_DIR="${OVERLAY_DIR:?missing OVERLAY_DIR}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1607472000}"

DOWNLOADS_DIR="${DOWNLOADS_DIR:-${REPO_ROOT}/openwrt-build/downloads}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/openwrt-build/output}"
OVERLAY_PATH="${REPO_ROOT}/${OVERLAY_DIR}"

if [[ ! -d "${OVERLAY_PATH}" ]]; then
  echo "Overlay directory not found: ${OVERLAY_PATH}" >&2
  exit 2
fi

mkdir -p "${DOWNLOADS_DIR}" "${OUTPUT_DIR}"

if [[ ! -f "${DOWNLOADS_DIR}/${IMAGEBUILDER_NAME}" ]]; then
  curl -fL "${IMAGEBUILDER_URL}" -o "${DOWNLOADS_DIR}/${IMAGEBUILDER_NAME}"
fi

check_sha256 "${IMAGEBUILDER_SHA256}" "${DOWNLOADS_DIR}/${IMAGEBUILDER_NAME}"

docker run --rm \
  -e IMAGEBUILDER_NAME="${IMAGEBUILDER_NAME}" \
  -e TARGET_SUBDIR="${TARGET_SUBDIR}" \
  -e PROFILE="${PROFILE}" \
  -e PACKAGES="${PACKAGES}" \
  -e OUTPUT_TAG="${OUTPUT_TAG}" \
  -e OVERLAY_DIR="${OVERLAY_DIR}" \
  -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
  -v "${REPO_ROOT}:/work/repo" \
  debian:11 bash -lc '
set -euo pipefail
export SOURCE_DATE_EPOCH

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential ca-certificates file gawk gettext git libncurses5-dev \
  libssl-dev python2 python-is-python2 python3 rsync unzip wget xz-utils zlib1g-dev

rm -rf /tmp/openwrt-imagebuilder
mkdir -p /tmp/openwrt-imagebuilder
tar -xJf "/work/repo/openwrt-build/downloads/${IMAGEBUILDER_NAME}" \
  -C /tmp/openwrt-imagebuilder --strip-components=1

make -C /tmp/openwrt-imagebuilder info > "/work/repo/openwrt-build/output/make-info-${OUTPUT_TAG}.txt"
make -C /tmp/openwrt-imagebuilder image \
  PROFILE="${PROFILE}" \
  FILES="/work/repo/${OVERLAY_DIR}" \
  PACKAGES="${PACKAGES}" \
  2>&1 | tee "/work/repo/openwrt-build/output/build-${OUTPUT_TAG}.log"

rm -rf "/work/repo/openwrt-build/output/${OUTPUT_TAG}"
mkdir -p "/work/repo/openwrt-build/output/${OUTPUT_TAG}"
cp -v /tmp/openwrt-imagebuilder/bin/targets/"${TARGET_SUBDIR}"/*"${PROFILE}"* \
  "/work/repo/openwrt-build/output/${OUTPUT_TAG}/"
'

ls -lh "${OUTPUT_DIR}/${OUTPUT_TAG}"
print_sha256 "${OUTPUT_DIR}/${OUTPUT_TAG}"/*.bin
