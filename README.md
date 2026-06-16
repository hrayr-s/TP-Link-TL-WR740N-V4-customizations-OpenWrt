# TP-Link TL-WR740N v4 OpenWrt VPN/WDS Image

This repository builds a small OpenWrt image for the TP-Link TL-WR740N/ND v4
using the official OpenWrt 18.06.9 `ar71xx/tiny` ImageBuilder profile.

The image is designed for an old 4 MB flash router used as a lightweight
wireless gateway:

- no LuCI web UI
- WAN routing removed by default
- physical WAN port bridged into LAN
- WireGuard helper scripts included
- WDS bridge and routed WDS gateway helper scripts included
- local LAN subnet and DHCP range configured from SSH

This project does not repack TP-Link vendor firmware. It uses the OpenWrt
ImageBuilder plus a small overlay, and it does not modify ART/calibration data
or the bootloader.

## Repository Layout

```text
profiles/                         Build profiles for OpenWrt targets
overlays/tl-wr740n-v4-vpn-wds/    Files copied into the OpenWrt rootfs
scripts/                          Reusable build entry points
openwrt-build/                    Build cache, output, and legacy wrapper
analysis/                         Firmware analysis report and local artifacts
docs/                             Additional notes as the project grows
```

Generated firmware, downloaded ImageBuilder archives, and extracted vendor
firmware contents are ignored by Git. Keep original OEM images and extracted
root filesystems local unless you have a clear redistribution right.

## Build

Prerequisites:

- Docker
- `curl`
- `shasum` or `sha256sum`

## Fresh Clone Build

From a clean machine with Docker installed:

```sh
git clone git@github.com:hrayr-s/TP-Link-TL-WR740N-V4-customizations-OpenWrt.git
cd TP-Link-TL-WR740N-V4-customizations-OpenWrt
docker --version
./scripts/build-openwrt-image.sh
```

The build script downloads the official OpenWrt ImageBuilder archive, verifies
its SHA256, runs ImageBuilder inside a Debian 11 Docker container, applies the
overlay from `overlays/tl-wr740n-v4-vpn-wds/files`, and writes images to:

```text
openwrt-build/output/images-vpn-wds/
```

Expected output files:

```text
openwrt-18.06.9-ar71xx-tiny-tl-wr740n-v4-squashfs-factory.bin
openwrt-18.06.9-ar71xx-tiny-tl-wr740n-v4-squashfs-sysupgrade.bin
openwrt-18.06.9-ar71xx-tiny-device-tl-wr740n-v4.manifest
```

Verify the generated images:

```sh
shasum -a 256 openwrt-build/output/images-vpn-wds/*.bin
file openwrt-build/output/images-vpn-wds/*.bin
```

Current expected hashes:

```text
ea3b1c1c7f024623c980a027bc4d4c24c98c1cdeaf50e9f7918e7580282c92c4  openwrt-18.06.9-ar71xx-tiny-tl-wr740n-v4-squashfs-factory.bin
e60fe3241664cd2b46760043ce15d3e6a643d927a734c23d5d158084d706c651  openwrt-18.06.9-ar71xx-tiny-tl-wr740n-v4-squashfs-sysupgrade.bin
```

The original TP-Link OEM firmware images are not required to build this custom
OpenWrt image. They were used only for local analysis and are intentionally not
part of the public repository.

## Build Options

Build the default TL-WR740N v4 image:

```sh
./scripts/build-openwrt-image.sh
```

The compatibility wrapper still works:

```sh
./openwrt-build/build-tl-wr740n-v4.sh
```

Build outputs are written to:

```text
openwrt-build/output/images-vpn-wds/
```

To add another OpenWrt target, create a new file in `profiles/` and point the
builder at it:

```sh
PROFILE_CONFIG=profiles/my-target.env ./scripts/build-openwrt-image.sh
```

## Current Profile

The default profile is [profiles/tl-wr740n-v4-vpn-wds.env](profiles/tl-wr740n-v4-vpn-wds.env).

It builds:

- OpenWrt `18.06.9`
- target `ar71xx/tiny`
- profile `tl-wr740n-v4`
- overlay `overlays/tl-wr740n-v4-vpn-wds/files`

The firmware is intentionally minimal because the router has only 4 MB flash.
See [openwrt-build/README.md](openwrt-build/README.md) for current image hashes,
flashing notes, SSH usage, WDS gateway setup, troubleshooting, and WireGuard
helper usage.

## Safety

Only flash firmware built for the exact hardware revision. For this repository,
that is `TP-Link TL-WR740N/ND v4`. Have a recovery path ready before flashing:
UART serial access is strongly preferred, and TFTP recovery should be verified
for the exact device revision.

Use:

- `factory.bin` only for first install from the TP-Link OEM web UI or a
  compatible recovery path.
- `sysupgrade.bin` only after the router is already running OpenWrt.

Do not write to ART/calibration partitions.
