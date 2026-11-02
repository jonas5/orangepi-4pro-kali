#!/bin/bash
# ==============================================================================
# build-kali-image.sh — Build Bootable Kali Linux SD Image for Orange Pi 4 Pro
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/output"
BUILD_DATE="$(date +%Y%m%d)"
IMAGE_NAME="kali-linux-${BUILD_DATE}-orangepi4pro-arm64.img"

echo "========================================================================"
echo "  Building Kali Linux Rolling SD Card Image for Orange Pi 4 Pro"
echo "========================================================================"

mkdir -p "${OUTPUT_DIR}"

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or with sudo)."
    exit 1
fi

# Ensure required tools
for tool in debootstrap parted losetup e2fsprogs mkfs.ext4 xz; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[-] Missing required build tool: $tool"
        exit 1
    fi
done

echo "[*] Step 1: Checking kernel, DTB, and modules..."
if [ ! -f "${REPO_ROOT}/boot/boot.scr" ]; then
    echo "[*] Compiling U-Boot boot.scr..."
    mkimage -C none -A arm -T script -d "${REPO_ROOT}/boot/boot.cmd" "${REPO_ROOT}/boot/boot.scr"
fi

echo "[*] Step 2: Preparing image workspace in ${OUTPUT_DIR}..."
TARGET_IMG="${OUTPUT_DIR}/${IMAGE_NAME}"
WORK_MNT="${OUTPUT_DIR}/rootfs_mnt"
mkdir -p "${WORK_MNT}"

# Create sparse raw disk image (4.5 GB)
echo "[*] Creating 4.5 GB raw disk image: ${TARGET_IMG}..."
truncate -s 4800M "${TARGET_IMG}"

# Partition disk layout:
# Offset 0 - 2047: Bootloader / SPL space (Allwinner A733 loads SPL at 8K and U-Boot at 40K)
# Partition 1: Sector 2048 to end, Ext4 rootfs (marked bootable)
echo "[*] Partitioning disk image..."
parted -s "${TARGET_IMG}" mklabel msdos
parted -s "${TARGET_IMG}" mkpart primary ext4 2048s 100%
parted -s "${TARGET_IMG}" set 1 boot on

# Loop device mapping
LOOP_DEV=$(losetup -fP --show "${TARGET_IMG}")
ROOT_PART="${LOOP_DEV}p1"
echo "[*] Loop device mapped to ${ROOT_PART}"

cleanup() {
    echo "[*] Cleaning up mounts and loop devices..."
    sync
    umount -lf "${WORK_MNT}/proc" 2>/dev/null || true
    umount -lf "${WORK_MNT}/sys" 2>/dev/null || true
    umount -lf "${WORK_MNT}/dev/pts" 2>/dev/null || true
    umount -lf "${WORK_MNT}/dev" 2>/dev/null || true
    umount -lf "${WORK_MNT}" 2>/dev/null || true
    losetup -d "${LOOP_DEV}" 2>/dev/null || true
}
trap cleanup EXIT

echo "[*] Formatting root partition as ext4 (label: KALI_ROOT)..."
mkfs.ext4 -F -L "KALI_ROOT" -b 4096 -O ^metadata_csum_seed "${ROOT_PART}"
mount "${ROOT_PART}" "${WORK_MNT}"

echo "[*] Step 3: Debootstrapping Kali Linux Rolling ARM64 rootfs..."
# Verify or install kali-archive-keyring
KALI_MIRROR="http://http.kali.org/kali"
KEYRING_ARG=""
if [ -f "/usr/share/keyrings/kali-archive-keyring.gpg" ]; then
    KEYRING_ARG="--keyring=/usr/share/keyrings/kali-archive-keyring.gpg"
fi

debootstrap --arch=arm64     --include=kali-archive-keyring,sudo,systemd,udev,dbus,network-manager,locales,curl,wget,ca-certificates,pciutils,usbutils,ethtool,kmod,net-tools,wireless-tools,iw,iproute2,openssh-server     ${KEYRING_ARG}     kali-rolling "${WORK_MNT}" "${KALI_MIRROR}"

echo "[*] Step 4: Installing boot configuration, DTBs, and kernel..."
mkdir -p "${WORK_MNT}/boot/allwinner" "${WORK_MNT}/boot/dtb/allwinner"
cp "${REPO_ROOT}/boot/boot.scr" "${WORK_MNT}/boot/boot.scr"
cp "${REPO_ROOT}/boot/boot.cmd" "${WORK_MNT}/boot/boot.cmd"
cp "${REPO_ROOT}/boot/orangepiEnv.txt" "${WORK_MNT}/boot/orangepiEnv.txt"

# Copy device tree if compiled in build or dts
if [ -f "${REPO_ROOT}/dts/sun60i-a733-orangepi-4-pro.dtb" ]; then
    cp "${REPO_ROOT}/dts/sun60i-a733-orangepi-4-pro.dtb" "${WORK_MNT}/boot/allwinner/"
    cp "${REPO_ROOT}/dts/sun60i-a733-orangepi-4-pro.dtb" "${WORK_MNT}/boot/dtb/allwinner/"
fi

# Step 5: Copy Kali system overlays
echo "[*] Step 5: Applying Kali Linux overlay files..."
cp -rv "${REPO_ROOT}/overlay/"* "${WORK_MNT}/"

echo "[*] Step 6: Configuring user accounts & system services in chroot..."
mount --bind /dev "${WORK_MNT}/dev"
mount --bind /dev/pts "${WORK_MNT}/dev/pts"
mount --bind /proc "${WORK_MNT}/proc"
mount --bind /sys "${WORK_MNT}/sys"

chroot "${WORK_MNT}" /bin/bash -c "
export DEBIAN_FRONTEND=noninteractive

# Set root password
echo 'root:toor' | chpasswd

# Setup default kali user
if ! id -u kali >/dev/null 2>&1; then
    useradd -m -s /bin/bash -u 1000 -G sudo,audio,video,plugdev,netdev,dialout kali
    echo 'kali:kali' | chpasswd
    echo 'kali ALL=(ALL:ALL) ALL' > /etc/sudoers.d/kali
    chmod 0440 /etc/sudoers.d/kali
fi

# Enable critical services
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable ssh.service 2>/dev/null || true
systemctl enable kali-firstboot-growpart.service 2>/dev/null || true

# Generate default locale
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Install Kali core pentesting metapackage
apt-get update
apt-get install -y --no-install-recommends kali-linux-core aircrack-ng tcpdump nmap
apt-get clean
"

echo "[*] Step 7: Finalizing image and unmounting..."
cleanup
trap - EXIT

echo "[*] Step 8: Compressing image with xz..."
xz -T0 -9 -c "${TARGET_IMG}" > "${TARGET_IMG}.xz"
sha256sum "${TARGET_IMG}.xz" > "${TARGET_IMG}.xz.sha256"

echo "[✓] Kali Linux build complete!"
echo "    - Image Archive: ${TARGET_IMG}.xz"
echo "    - SHA256 Checksum: $(cat "${TARGET_IMG}.xz.sha256")"
