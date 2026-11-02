#!/bin/bash
# ==============================================================================
# compile-kali-kernel.sh — Cross-compile Linux 6.18 with Kali Injection for A733
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build_kernel"
KERNEL_BRANCH="linux-6.18.y"
KERNEL_REPO="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

ARCH="arm64"
CROSS_COMPILE="aarch64-linux-gnu-"

echo "[*] Preparing kernel build workspace in ${BUILD_DIR}..."
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

if [ ! -d "linux-6.18" ]; then
    echo "[*] Cloning mainline ${KERNEL_BRANCH}..."
    git clone --depth 1 --branch "${KERNEL_BRANCH}" "${KERNEL_REPO}" linux-6.18
fi

cd linux-6.18

echo "[*] Applying Orange Pi 4 Pro Allwinner A733 mainline patch..."
git checkout -f
git clean -fd
git apply "${REPO_ROOT}/patch/0001-allwinner-a733-orangepi-4-pro-6.18-mainline.patch"

echo "[*] Applying Kali Linux mac80211 monitor & injection patch..."
if [ -f "${REPO_ROOT}/patch/0002-kali-mac80211-injection.patch" ]; then
    git apply "${REPO_ROOT}/patch/0002-kali-mac80211-injection.patch" || true
fi

echo "[*] Applying Armbian builddeb packaging patch..."
if [ -f "${REPO_ROOT}/patch/0300-packaging-armbian-builddeb.patch" ]; then
    git apply "${REPO_ROOT}/patch/0300-packaging-armbian-builddeb.patch" || true
fi

echo "[*] Copying Kali Linux pentesting kernel configuration..."
cp "${REPO_ROOT}/config/orangepi_4pro_kali_defconfig" .config
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} olddefconfig

echo "[*] Compiling Image, DTBs, and Modules (-j$(nproc))..."
make -j"$(nproc)" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} Image dtbs modules

echo "[✓] Kernel build complete:"
echo "    - Image: ${BUILD_DIR}/linux-6.18/arch/arm64/boot/Image"
echo "    - DTB:   ${BUILD_DIR}/linux-6.18/arch/arm64/boot/dts/allwinner/sun60i-a733-orangepi-4-pro.dtb"
