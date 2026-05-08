#!/usr/bin/env bash
set -euo pipefail

LAB_PLATFORM_ROOT="${LAB_PLATFORM_ROOT:-/srv/lab-platform}"
df -h "$LAB_PLATFORM_ROOT"
du -h -d 2 "$LAB_PLATFORM_ROOT/data" 2>/dev/null | sort -h
