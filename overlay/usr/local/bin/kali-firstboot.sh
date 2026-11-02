#!/bin/bash
set -eu

echo "[*] Running Kali Linux first-boot initialization..."

# 1. Expand root filesystem
if command -v growpart >/dev/null 2>&1; then
    echo "[*] Expanding root partition /dev/mmcblk0p1..."
    growpart /dev/mmcblk0 1 || true
    resize2fs /dev/mmcblk0p1 || true
fi

# 2. Generate SSH host keys if missing
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[*] Generating SSH host keys..."
    ssh-keygen -A || true
fi

# 3. Ensure kali user exists
if ! id -u kali >/dev/null 2>&1; then
    echo "[*] Creating default kali user..."
    useradd -m -s /bin/bash -u 1000 -G sudo,audio,video,plugdev,netdev,dialout kali || true
    echo "kali:kali" | chpasswd || true
    echo "kali ALL=(ALL:ALL) ALL" > /etc/sudoers.d/kali
    chmod 0440 /etc/sudoers.d/kali
fi

# 4. Set hostname
hostnamectl set-hostname kali-orangepi4pro 2>/dev/null || true

echo "[✓] Kali Linux first-boot setup completed."
