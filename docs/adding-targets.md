# Adding Another OpenWrt Target

The build script is profile-driven. Add one file under `profiles/` for each
OpenWrt target and one overlay under `overlays/` for the rootfs files that are
specific to that target or image variant.

## Profile File

Use `profiles/tl-wr740n-v4-vpn-wds.env` as the template:

```sh
: "${OPENWRT_RELEASE:=18.06.9}"
: "${TARGET_SUBDIR:=ar71xx/tiny}"
: "${IMAGEBUILDER_NAME:=openwrt-imagebuilder-18.06.9-ar71xx-tiny.Linux-x86_64.tar.xz}"
: "${IMAGEBUILDER_URL:=https://downloads.openwrt.org/releases/18.06.9/targets/ar71xx/tiny/${IMAGEBUILDER_NAME}}"
: "${IMAGEBUILDER_SHA256:=...}"

: "${PROFILE:=tl-wr740n-v4}"
: "${OUTPUT_TAG:=images-vpn-wds}"
: "${OVERLAY_DIR:=overlays/tl-wr740n-v4-vpn-wds/files}"
: "${SOURCE_DATE_EPOCH:=1607472000}"

: "${PACKAGES:=wireguard -tcpdump-mini -ppp -ppp-mod-pppoe -ip6tables -odhcp6c -odhcpd-ipv6only}"
```

Run:

```sh
PROFILE_CONFIG=profiles/my-target.env ./scripts/build-openwrt-image.sh
```

## Overlay Rules

Keep overlays small and target-specific. For OpenWrt, prefer UCI defaults,
package selection, and helper scripts over unpacking and repacking generated
root filesystems.

Do not include per-device calibration data, MAC addresses, ART/EEPROM dumps,
private VPN keys, passwords, or extracted vendor rootfs contents.

## Validation

For each new target, record at least:

- exact device model and hardware revision
- ImageBuilder release and target subdirectory
- OpenWrt profile name
- factory and sysupgrade image sizes and hashes
- `file` output for the generated images
- `binwalk` offsets for kernel and rootfs
- recovery path verified for that device
