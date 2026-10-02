#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" = 0 || { echo 'Run this installer with sudo.'; exit 1; }
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test ! -L /usr/local/lib/ai-usage-gpu-probe
install -d -o root -g root -m 0755 /usr/local/lib/ai-usage-gpu-probe
install -o root -g root -m 0644 "$source_dir/gpu_probe.py" /usr/local/lib/ai-usage-gpu-probe/gpu_probe.py
install -o root -g root -m 0644 "$source_dir/ai-usage-gpu-probe.service" /etc/systemd/system/ai-usage-gpu-probe.service
systemctl daemon-reload
systemctl enable --now ai-usage-gpu-probe.service
echo 'GPU counter helper installed. No AI apps were restarted.'
