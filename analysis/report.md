# TP-Link TL-WR740N v4 Firmware Comparison

## Inputs

| Image | Version | Size | SHA-256 |
| --- | --- | ---: | --- |
| `TL-WR740N_V4_140814_RU.bin` | 3.13.2 | 4,063,744 | `42298942a8cd454a29c4c5c461839173dd35d69214d4a0545f0f78ccd9a707dd` |
| `wr740nv4_en_3_17_0_up_boot(150105).bin` | 3.17.0 | 4,063,744 | `08642b1588ab8a676672b41c27c9686f38ae781e7a743b5d8c0875ef593f4bd6` |

Both images identify as TP-Link WR740 v4 containers:

- Vendor: `TP-LINK Technologies`
- Header version: `ver. 1.0`
- Hardware ID: `0x07400004`
- Hardware revision: `1`
- Outer firmware length: `0x3e0200`
- Inner firmware length: `0x3c0000`

## Layout

These are bootloader-inclusive firmware images:

| Region | File offset | Notes |
| --- | ---: | --- |
| Outer TP-Link header | `0x0` | 512 bytes |
| U-Boot region | `0x200` | 128 KiB |
| Inner TP-Link header | `0x20200` | 512 bytes |
| Kernel LZMA | `0x20400` | MIPS32, Linux 2.6.31 |
| SquashFS rootfs | `0x120200` | SquashFS 4.0, LZMA, 128 KiB blocks |

Kernel command line in both images:

`console=ttyS0,115200 root=31:02 rootfstype=squashfs init=/sbin/init mtdparts=ar7240-nor0:128k(u-boot),1024k(kernel),2816(rootfs),64k(config),64k(ART) mem=32M`

## Bootloader And Kernel

| Area | RU 3.13.2 | EN 3.17.0 |
| --- | --- | --- |
| U-Boot | `U-Boot 1.1.4 (Aug 14 2014 - 10:50:25)` / `AP121-2MB (ar9330) U-boot` | `U-Boot 1.1.4 (Jan 5 2015 - 17:01:20)` / `AP121 (ar9330) U-boot` |
| Kernel build | `Linux version 2.6.31--LSDK-9.2.0.312 ... #1 Thu Aug 14 10:52:33 CST 2014` | `Linux version 2.6.31--LSDK-9.2.0.312 ... #1 Mon Jan 5 17:03:22 CST 2015` |
| Kernel LZMA size | 895,158 | 894,069 |
| Kernel unpacked size | 2,596,996 | 2,589,452 |
| Kernel LZMA end | `0xfacb6` | `0xfa875` |
| Slack before rootfs | 152,906 bytes | 153,995 bytes |

Both kernels target Atheros AR9330/Hornet, MIPS32_R2 big-endian userspace, and 32 MB RAM.

## Root Filesystem

| Metric | RU 3.13.2 | EN 3.17.0 |
| --- | ---: | ---: |
| SquashFS created | 2014-08-14 06:56:08 | 2015-01-05 13:06:52 |
| SquashFS image size | 2,355,570 | 2,419,187 |
| Inodes | 574 | 544 |
| Regular files extracted | 399 | 364 |
| Symlinks extracted | 68 | 70 |
| Common files changed | 231 | 231 |
| Files only in this image | 41 | 6 |
| Rootfs slack to image end | 528,014 bytes | 464,397 bytes |

Extraction note: stock Homebrew `unsquashfs` could read the superblock but failed during extraction. A patched temporary `sasquatch`/SquashFS 4.3 `unsquashfs` build under `/tmp/sasquatch` extracted the filesystems. Device nodes under `/dev` were skipped because extraction was not run as root.

## Core Runtime

These files are byte-identical between images:

- `/etc/rc.d/rcS`
- `/etc/rc.d/rc.modules`
- `/etc/rc.d/rc.wlan`
- `/etc/inittab`
- `/etc/passwd`
- `/etc/shadow`
- `/etc/ath/wsc_config.txt`
- `/etc/lld2d.conf`

Boot still starts `/usr/bin/httpd` directly from `rcS`.

## Material Functional Differences

EN 3.17.0 adds:

- `web/userRpm/NatCfgRpm.htm` and `web/help/NatCfgHelpRpm.htm`
- `web/userRpm/EraseCal.htm`
- `lib/modules/2.6.31/kernel/nf_conntrack_sip.ko`
- `lib/modules/2.6.31/kernel/nf_nat_sip.ko`
- `lib/libexec/xtables/libxt_CONNMARK.so`
- `bin/ethreg -> busybox`
- `bin/ln -> busybox`

EN `httpd` includes NAT and WAN-event symbols not present in RU, including `httpNatCfgInit`, `swSetNatCfg`, `swIsNatEnable`, `getNatShowWebPage`, `setWanPlugedInFlag`, `setWanPlugedOutFlag`, `isWanPlugedInEvent`, and `isWanPlugedOutEvent`.

RU 3.13.2 adds or retains:

- ISP auto-configuration wizard: `web/dynaform/ispAutoConf.js`, `web/userRpm/WzdAutoConfRpm.htm`
- bridge/VLAN mode pages: `web/userRpm/LanBrModeRpm.htm`, `web/help/BridgeHelpRpm.htm`, `web/help/VlanTagCfgHelpRpm.htm`
- extra WPA2 example configs under `/etc/wpa2`
- `sbin/repeater_pass_configuration`
- several NAS/media placeholder pages under `web/userRpm`

RU menu emphasizes `WorkingModeRpm`, `LanBrModeRpm`, ISP auto config, and Russian localization. EN menu emphasizes `OperModeRpm`, `ConnModeCfgRpm`, `MobileCfgRpm`, and `NatCfgRpm`.

## Binaries

| Binary | RU 3.13.2 | EN 3.17.0 | Notes |
| --- | ---: | ---: | --- |
| `/bin/busybox` | 267,652 | 281,924 | EN has extra `ethreg`/switch-register usage strings |
| `/usr/bin/httpd` | 1,278,252 | 1,426,816 | EN adds NAT and WAN-event handlers |
| `/sbin/hostapd` | 356,632 | 356,600 | changed, similar size |
| `/usr/sbin/pppd` | 337,868 | 340,520 | changed |

Both userspaces are MIPS32_R2 big-endian ELF binaries using `/lib/ld-uClibc.so.0`.

## Risk Notes

- Both images contain U-Boot. Flashing one of these writes more than just kernel/rootfs on workflows that honor the full image layout; confirm recovery before using them.
- Neither image includes `config` or `ART` in the payload, based on the kernel MTD layout and image length. Do not overwrite ART/calibration separately.
- EN-only `EraseCal.htm` posts to a hidden/debug-looking calibration erase endpoint and warns that radio data will be erased. Treat this as hazardous on a live device.
- EN adds SIP NAT helper modules, but `rc.modules` does not insert them at boot. They are probably used on demand by `httpd`/iptables helper paths.
- Root/Admin credential material in `/etc/passwd` and `/etc/shadow` is identical across both images.

## Generated Artifacts

- Extracted sections and rootfs trees are under `analysis/ru_3_13_2/` and `analysis/en_3_17_0/`.
- File comparison lists:
  - `analysis/only_ru_files.txt`
  - `analysis/only_en_files.txt`
  - `analysis/changed_common_files.txt`
  - `analysis/only_ru_symlinks.txt`
  - `analysis/only_en_symlinks.txt`
