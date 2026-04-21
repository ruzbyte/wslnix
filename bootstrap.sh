#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/nixos-wsl"
CONFIG_FILE="$CONFIG_DIR/user.nix"

mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
  echo "Config already exists at $CONFIG_FILE"
  cat "$CONFIG_FILE"
  echo ""
  read -p "Overwrite? (y/N): " overwrite
  if [ "$overwrite" != "y" ]; then
    exit 0
  fi
fi

echo "=== NixOS-WSL Bootstrap ==="
echo ""

read -p "Username: " username
while [ -z "$username" ]; do
  echo "Username cannot be empty."
  read -p "Username: " username
done

read -p "Git email: " email
while [ -z "$email" ]; do
  echo "Email cannot be empty."
  read -p "Git email: " email
done

# Nix-File schreiben
cat > "$CONFIG_FILE" <<EOF
{
  username = "$username";
  email = "$email";
}
EOF

echo ""
echo "✓ Written to $CONFIG_FILE"
cat "$CONFIG_FILE"
echo ""
echo "Now run: sudo nixos-rebuild switch --flake .#wsl"
