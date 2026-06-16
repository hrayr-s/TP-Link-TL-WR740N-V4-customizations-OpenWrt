# TL-WR740N v4 OpenWrt Build Notes

This directory holds the local ImageBuilder cache, build output, and a legacy
wrapper for the custom OpenWrt image for `TP-Link TL-WR740N/ND v4`.

The reusable build entry point is now [scripts/build-openwrt-image.sh](../scripts/build-openwrt-image.sh), configured by [profiles/tl-wr740n-v4-vpn-wds.env](../profiles/tl-wr740n-v4-vpn-wds.env). The rootfs overlay lives in [overlays/tl-wr740n-v4-vpn-wds/files](../overlays/tl-wr740n-v4-vpn-wds/files).

This workflow does not repack the TP-Link vendor firmware and does not touch ART/calibration data or the bootloader. OpenWrt 18.06.9 is old and unsupported, but it is the practical official ImageBuilder line that still has this 4 MB flash target profile.

## Rebuild

Prerequisite: Docker.

```sh
./scripts/build-openwrt-image.sh
```

The old wrapper remains available:

```sh
./openwrt-build/build-tl-wr740n-v4.sh
```

Defaults:

- Profile: `tl-wr740n-v4`
- Profile config: `profiles/tl-wr740n-v4-vpn-wds.env`
- Overlay: `overlays/tl-wr740n-v4-vpn-wds/files`
- Packages added: `wireguard`
- Packages removed: `tcpdump-mini ppp ppp-mod-pppoe ip6tables odhcp6c odhcpd-ipv6only`
- Build timestamp: `SOURCE_DATE_EPOCH=1607472000`
- WAN routing removed: `wan` and `wan6` are deleted on first boot
- Physical WAN port converted into LAN: `network.lan.ifname='eth0.1 eth1'`
- Firewall has no WAN zone by default

Override the package set if needed:

```sh
PACKAGES="-ip6tables -odhcp6c -odhcpd-ipv6only" OUTPUT_TAG=images-overlay-only ./scripts/build-openwrt-image.sh
```

Build another target by creating a profile file and passing it through
`PROFILE_CONFIG`:

```sh
PROFILE_CONFIG=profiles/my-target.env ./scripts/build-openwrt-image.sh
```

## Current Output

Built images are in `openwrt-build/output/images-vpn-wds/`.

| Image | Size | SHA256 |
| --- | ---: | --- |
| `openwrt-18.06.9-ar71xx-tiny-tl-wr740n-v4-squashfs-factory.bin` | 3,932,160 bytes | `ea3b1c1c7f024623c980a027bc4d4c24c98c1cdeaf50e9f7918e7580282c92c4` |
| `openwrt-18.06.9-ar71xx-tiny-tl-wr740n-v4-squashfs-sysupgrade.bin` | 3,342,340 bytes | `e60fe3241664cd2b46760043ce15d3e6a643d927a734c23d5d158084d706c651` |

Validated layout:

- TP-Link/OpenWrt header reports `firmware 740 v4 OpenWrt r8077-7cbbab7246`
- Kernel LZMA offset: `0x200`
- SquashFS rootfs offset: `0x14de50`
- SquashFS rootfs size: `1953370` bytes
- Rootfs contains the VPN/WDS banner, hostname default, WireGuard packages, and helper scripts in `/usr/sbin`, including `wds-gateway-setup`

## SSH Usage

Connect:

```sh
ssh -oHostKeyAlgorithms=+ssh-rsa root@192.168.1.1
```

Useful included helpers:

```sh
router-mode-status
wds-setup --help
wds-gateway-setup --help
vpn-wg-profile --help
vpn-wg-disable
```

Configure WDS:

```sh
wds-setup 'UPSTREAM_SSID' 'UPSTREAM_WIFI_PASSWORD' 'LOCAL_SSID' 'LOCAL_WIFI_PASSWORD' 'AM'
```

The upstream AP must support WDS/4-address bridging. The radio is set to channel `auto`; in WDS station mode it follows the upstream AP channel. If you bridge into an existing LAN with another DHCP server, disable this router's DHCP server after you confirm the management IP:

```sh
uci set dhcp.lan.ignore='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

Configure WDS as a routed gateway:

```sh
wds-gateway-setup 192.168.50.1/24 192.168.50.100 192.168.50.199 'UPSTREAM_SSID' 'UPSTREAM_WIFI_PASSWORD' 'LOCAL_SSID' 'LOCAL_WIFI_PASSWORD' 'AM'
```

This creates a logical wireless uplink named `wdswan`, enables NAT from LAN to
`wdswan`, and sets the local DHCP range from the two full IP addresses. Choose a
local `/24` subnet that does not overlap the upstream Wi-Fi network, for example
`192.168.50.0/24` if the upstream network is already `192.168.1.0/24`.

Check WDS gateway status after reconnecting to the new LAN address:

```sh
wifi status
ifstatus wdswan
logread | tail -80
```

The setup command has committed the config if it prints lines like:

```text
Committed LAN IP: 192.168.50.1
Committed wdswan proto: dhcp
Committed WDS SSID: UPSTREAM_SSID
```

The TL-WR740N v4 radio is 2.4 GHz only. Do not use a `5G`/5 GHz upstream SSID;
use the upstream router's 2.4 GHz SSID. If `ifstatus wdswan` does not become
`"up": true`, the wireless client did not receive an upstream DHCP lease.

These messages are common during startup:

- `udhcpc: no lease, failing`: the router did not get DHCP on `wdswan`; check
  the SSID, password, 2.4 GHz band, upstream WDS support, and upstream DHCP.
- `Warning: Unable to locate ipset utility`: harmless for this image.
- `Section 'wdswan' cannot resolve device`: expected until the Wi-Fi station
  associates and creates the client interface.

If the upstream router does not support WDS/4-address mode, use ordinary Wi-Fi
station mode for the routed gateway:

```sh
uci -q delete wireless.wds_up.wds || true
uci commit wireless
wifi reload
ifup wdswan
sleep 15
ifstatus wdswan
```

Expected success is `ifstatus wdswan` showing `"up": true`, an IPv4 address from
the upstream router, and a default route/gateway.

Configure WireGuard:

```sh
vpn-wg-profile '<private-key>' '10.8.0.2/32' '<peer-public-key>' '203.0.113.10:51820' '0.0.0.0/0' '1.1.1.1' '192.168.1.1'
```

The last argument is the normal upstream LAN gateway. It is used only when the WireGuard endpoint is a plain IPv4 address, so the endpoint remains reachable outside the VPN default route. LAN clients that should use the VPN should use this router's LAN IP as their default gateway.

## Flashing Notes

Use the `factory.bin` image only for first install from the TP-Link OEM web UI or a compatible recovery/TFTP path. Use the `sysupgrade.bin` image only after the router is already running OpenWrt.

Before flashing, have a recovery path ready: UART access is strongly preferred, and TFTP recovery should be tested for this exact hardware revision. Do not write anything to the ART/calibration partition.
