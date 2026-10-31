#!/usr/bin/env bash
set -euo pipefail

echo "$SSH_PRIVATE_KEY_B64" | base64 -d | tr -d '\r'
