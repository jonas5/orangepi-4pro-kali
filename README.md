# Allwinner A733 Linux Support — Kali Linux Rolling (Linux 6.18.y)

[![Build & Release Kali Linux Image](https://github.com/jonas5/orangepi-4pro-kali/actions/workflows/build-kali-image.yml/badge.svg)](https://github.com/jonas5/orangepi-4pro-kali/actions/workflows/build-kali-image.yml)
[![Kernel Branch](https://img.shields.io/badge/Kernel-Linux%206.18.y%20ARM64-blue.svg)](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git)
[![Kali Release](https://img.shields.io/badge/Distribution-Kali%20Linux%20Rolling-red.svg)](https://www.kali.org/)
[![Packet Injection](https://img.shields.io/badge/Packet%20Injection-Patched%20mac80211-brightgreen.svg)]()

This repository provides the official Kali Linux Rolling ARM64 operating system image, kernel baseline, device trees, packet injection patches, and automated GitHub Actions CI build pipelines for the **Orange Pi 4 Pro (Allwinner A733 / `sun60iw2`)**.

---

## 1. Hardware & Pentesting Feature Matrix

| Feature | Hardware Specification | Kali Linux Status | Driver & Pentesting Architecture |
| :--- | :--- | :--- | :--- |
| **CPU / Architecture** | Allwinner A733 (6× Cortex-A55, 2× Cortex-A76) | **Working** | Mainline ARM64 DT, CCU clock tree, PCK-600 power controller |
| **Ethernet** | Motorcomm YT8531 1Gbps PHY | **Working** | `stmmac.ko` + `motorcomm.ko` (EEE & auto-sleep disabled, 0% packet loss) |
| **MicroSD** | SDC0 (`mmc@4020000`) | **Working** | Locked as `/dev/mmcblk0p1` via DT `aliases { mmc0 = &mmc0; }` |
| **Wireless (On-Board)** | AIC8800D80 SDIO 4-bit (`wlan0`) | **Working** | 802.11ax Wi-Fi 6 FullMAC + HE80 AP master mode (`aic8800_fdrv.ko`) |
| **Bluetooth** | AIC8800D80 UART1 (`hci0`) | **Working** | Native H4 1.5MBaud hardware flow control attach daemon |
| **GPU / Vulkan** | PowerVR Rogue BXM-4-64 (`36.56.104.183`) | **Working** | DRM `/dev/dri/renderD128` + Mesa open-source Vulkan 1.2 stack |
| **Wireless Injection** | Linux mac80211 / cfg80211 core | **Enabled** | Custom raw 802.11 frame injection patch, monitor mode channel lock bypass |
| **USB Pentesting Dongles** | Alfa AWUS036NEH, AWUS036ACH, Panda, TP-Link | **Supported** | `ath9k_htc`, `carl9170`, `rtl8187`, `rt2800usb`, `rtl8xxxu`, `mt7601u` |
| **SDR (Software Radio)** | RTL-SDR, HackRF, Airspy USB Dongles | **Supported** | `rtl2832`, `rtl2832_sdr`, `dvb_usb_rtl28xxu` modules built-in |
| **Automotive / CAN** | SocketCAN, Virtual CAN, Serial CAN | **Supported** | `can`, `can_raw`, `can_bcm`, `vcan`, `slcan` kernel modules |

> **Hardware Acceleration & Wi-Fi 6 AP Driver Packages (Free):**  
> To keep the public kernel tree clean and GPLv2 compliant, out-of-tree binary modules (AIC8800 Wi-Fi 6 Master/AP mode and PowerVR Rogue GPU Vulkan 1.2) are hosted separately as free binary packages on [**drivers.raccoon.ing**](https://drivers.raccoon.ing).  
>  
> <a href="https://buymeacoffee.com/jonas5" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="46" style="height: 46px !important;"></a>

---

## 2. Default Credentials & System Access

| Account | Username | Password | Privileges |
| :--- | :--- | :--- | :--- |
| **Default User** | `kali` | `kali` | Sudoer (`ALL=(ALL:ALL) ALL`), audio, video, plugdev, netdev, dialout |
| **Root User** | `root` | `toor` | Full root access (or `sudo su -`) |
| **Serial Console** | `ttyS0` | — | `115200` baud on UART0 header (pins 8 & 10) |
| **Hostname** | `kali-orangepi4pro` | — | Auto-resolved to `127.0.1.1` |
| **Rootfs Expansion**| — | — | Automatically expands partition to 100% disk size on first boot |

---

## 3. Wireless Monitor Mode & Packet Injection

The kernel includes the **Kali Linux mac80211 & cfg80211 raw packet injection patch** (`patch/0002-kali-mac80211-injection.patch`).

### Verifying Packet Injection (External USB Adapter):
```bash
# 1. Put wireless interface into monitor mode
sudo ip link set wlan1 down
sudo iw dev wlan1 set type monitor
sudo ip link set wlan1 up

# 2. Test packet injection with aireplay-ng
sudo aireplay-ng --test wlan1
```

### Supported Pentesting USB Wi-Fi Adapters Out-of-the-Box:
- **Atheros AR9271** (Alfa AWUS036NHA, TP-Link TL-WN722N v1): `ath9k_htc.ko`
- **Atheros AR9170** (carl9170): `carl9170.ko`
- **Realtek RTL8187L** (Alfa AWUS036H): `rtl8187.ko`
- **Ralink / MediaTek RT3070 / RT5370 / MT7601U** (Alfa AWUS036NEH, Panda): `rt2800usb.ko`, `mt7601u.ko`
- **Realtek RTL8812AU / RTL8814AU / RTL8821AU**: `rtl8xxxu.ko`

---

## 4. Hardware Driver Acceleration & Wi-Fi 6 Master AP License

While the core Linux kernel, Device Trees, and Kali Linux base OS are 100% open source, proprietary hardware acceleration drivers (PowerVR Rogue GPU Vulkan 1.2 stack and AIC8800 Wi-Fi 6 AP / Rogue AP mode) are maintained out-of-tree.

To activate the AIC8800 Wi-Fi 6 AP and Rogue Pentesting driver pack on your Orange Pi 4 Pro:

<a href="https://buymeacoffee.com/jonas5" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="46" style="height: 46px !important;"></a>

```bash
# 1. Run the client tool with your license key
sudo orangepi-config --activate kali_wifi_ap --payment-id YOUR-LICENSE-KEY --non-interactive

# 2. Launch the Wi-Fi 6 AP / Rogue AP
sudo /usr/local/bin/kali-wifi6-ap-setup.sh "Kali_WiFi6_AP" "KaliLinux2026" 5g 36

# 3. Or self-service lookup your license anytime at:
# https://raccoon.ing/activate
```

---

## 5. Repository Structure

```text
├── .github/
│   └── workflows/
│       ├── build-kali-image.yml  # Automated GitHub Actions workflow building Kali SD image (.img.xz)
│       ├── build-kernel.yml      # Automated workflow compiling kernel DEBs & DTBs
│       └── cleanup-runs.yml      # CI workflow maintenance helper
├── boot/
│   ├── boot.cmd                  # U-Boot boot script source
│   ├── boot.scr                  # Compiled U-Boot script
│   └── orangepiEnv.txt           # Boot arguments (cma=256M, panic=5, rootdev=/dev/mmcblk0p1)
├── config/
│   ├── orangepi_4pro_kali_defconfig # Kali pentesting modular Linux 6.18 kernel configuration
│   └── orangepi_4pro_defconfig      # Base mainline kernel configuration
├── dts/
│   ├── sun60i-a733-orangepi-4-pro.dts  # Board device tree
│   ├── sun60iw2p1.dtsi                 # SoC device tree
│   ├── sun60iw2p1-cpu-vf.dtsi          # CPU voltage-frequency table
│   └── include/dt-bindings/            # Device tree binding headers
├── overlay/                      # Kali Linux rootfs overlays
│   ├── etc/apt/sources.list.d/kali.list # Kali Rolling APT repository
│   ├── etc/motd                  # Kali Linux dragon ASCII banner
│   ├── etc/systemd/system/       # First-boot expansion & user provisioning services
│   └── usr/local/bin/            # First-boot script & a733-config / orangepi-config helper
├── patch/
│   ├── 0001-allwinner-a733-orangepi-4-pro-6.18-mainline.patch # Mainline 6.18 SoC patch
│   ├── 0002-kali-mac80211-injection.patch                     # Kali mac80211 injection patch
│   ├── 0300-packaging-armbian-builddeb.patch                  # Packaging fix
│   └── orangepi-build.patch                                   # Harness patch
├── scripts/
│   ├── build-kali-image.sh       # Standalone local Kali Linux SD image builder
│   └── compile-kali-kernel.sh    # Standalone kernel & DTB cross-compiler
└── README.md
```

---

## 6. Building with GitHub Actions CI

1. Fork or open this repository on GitHub.
2. Go to the **Actions** tab.
3. Select **Build & Release Kali Linux Image**.
4. Click **Run workflow** (choose `core`, `top10`, or `default` metapackage profile).
5. Download the resulting `kali-linux-orangepi4pro-6.18-arm64.img.xz` artifact or grab it from the Releases tab.

---

## 7. Flashing & Booting the Image

1. Decompress or directly flash the image using:
   - [BalenaEtcher](https://etcher.balena.io/) (Windows, macOS, Linux)
   - [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
   - Or terminal `dd`:
     ```bash
     xzcat kali-linux-orangepi4pro-6.18-arm64.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
     ```
2. Insert the MicroSD card into your Orange Pi 4 Pro.
3. Attach HDMI or connect serial debug console (`ttyS0` @ 115200 baud).
4. Power on with a 5V/4A or 12V Type-C power adapter.
5. Log in with `kali` / `kali`.

---

## 8. License

Kernel patches, device trees, and build scripts are dual-licensed under GPL-2.0 and MIT.
Kali Linux is a registered trademark of OffSec Services Limited.
