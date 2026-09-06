#!/usr/bin/env bash
#
# Install the SMS Code Filler native messaging setup for Firefox (macOS).
#
# - Installs the host (compiled binary if ./dist was built, otherwise the Python
#   source), the sms_common module, and the reader into ~/Library/Application Support/SMSFiller/
# - Registers the native-messaging manifest so Firefox can launch the host
# - Installs + loads a LaunchAgent (com.ye.smsfiller.reader) that owns Full Disk
#   Access and writes the codes cache the host reads
#
# Usage:  bash native/install.sh   (run this with ./dist present to use compiled binaries)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Find the distribution root containing dist/. Works whether install.sh sits at
# the repo root (next to dist/) or inside native/ (root is the parent).
if [ -d "${SCRIPT_DIR}/dist" ]; then
  ROOT="${SCRIPT_DIR}"
else
  ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
DIST="${ROOT}/dist"

EXT_ID="sms-code-filler@ye.local"
HOST_NAME="com.ye.smsfiller"
SESSION_LABEL="com.ye.smsfiller.reader"

INSTALL_DIR="$HOME/Library/Application Support/SMSFiller"
NM_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
NM_MANIFEST="${NM_DIR}/${HOST_NAME}.json"
LA_DIR="$HOME/Library/LaunchAgents"
LA_PLIST="${LA_DIR}/${SESSION_LABEL}.plist"

echo "==> SMS Code Filler installer"
echo

mkdir -p "${INSTALL_DIR}"

# Prefer compiled binaries if this machine built them (./dist). Otherwise fall
# back to the Python source (still works, but the code is readable).
# Choose the best compiled variant: universal2 works on any arch, otherwise the
# one matching the current machine. Fall back to the Python source.
COMPILED=0
COMPILED_DIR=""
if [ -x "${DIST}/universal2/sms_host" ] && [ -x "${DIST}/universal2/sms_reader" ]; then
  COMPILED_DIR="${DIST}/universal2"
elif [ "$(uname -m)" = "arm64" ] && [ -x "${DIST}/arm64/sms_host" ] && [ -x "${DIST}/arm64/sms_reader" ]; then
  COMPILED_DIR="${DIST}/arm64"
elif [ "$(uname -m)" = "x86_64" ] && [ -x "${DIST}/x86_64/sms_host" ] && [ -x "${DIST}/x86_64/sms_reader" ]; then
  COMPILED_DIR="${DIST}/x86_64"
fi
if [ -n "${COMPILED_DIR}" ]; then
  COMPILED=1
fi

if [ "${COMPILED}" = "1" ]; then
  echo "  Installing COMPILED (Nuitka) host from ${COMPILED_DIR}…"
  cp "${COMPILED_DIR}/sms_host" "${COMPILED_DIR}/sms_reader" "${INSTALL_DIR}/"
  # Nuitka standalone binaries link libpython via @executable_path, so copy it
  # beside them. (Cython builds used a sms_common*.so instead.)
  if ls "${COMPILED_DIR}"/libpython*.dylib >/dev/null 2>&1; then
    cp "${COMPILED_DIR}"/libpython*.dylib "${INSTALL_DIR}/"
  fi
  if ls "${COMPILED_DIR}"/sms_common*.so >/dev/null 2>&1; then
    cp "${COMPILED_DIR}"/sms_common*.so "${INSTALL_DIR}/"
  fi
  chmod +x "${INSTALL_DIR}/sms_host" "${INSTALL_DIR}/sms_reader"
  # Strip download quarantine/provenance so Gatekeeper doesn't block them. Do
  # NOT re-sign binaries that are already Developer-ID signed (notarized) — that
  # would strip the signature and invalidate the notarization ticket. Only
  # ad-hoc sign plain/unsigned binaries (e.g. a local build not yet notarized).
  for b in "${INSTALL_DIR}/sms_host" "${INSTALL_DIR}/sms_reader" "${INSTALL_DIR}"/libpython*.dylib; do
    [ -e "${b}" ] || continue
    xattr -c "${b}" >/dev/null 2>&1 || true
    if ! codesign -dv "${b}" 2>/dev/null | grep -qE "TeamIdentifier=[A-Z0-9]{10}"; then
      codesign --force --deep --sign - "${b}" >/dev/null 2>&1 || true
    fi
  done
  HOST_EXEC="${INSTALL_DIR}/sms_host"
  READER_ARGS=("${INSTALL_DIR}/sms_reader")
  FDA_TARGET="${INSTALL_DIR}/sms_reader"
else
  echo "  Installing Python source host…"
  cp "${SCRIPT_DIR}/sms_host.py" "${SCRIPT_DIR}/sms_common.py" "${SCRIPT_DIR}/sms_reader.py" "${INSTALL_DIR}/"
  chmod +x "${INSTALL_DIR}/sms_host.py" "${INSTALL_DIR}/sms_reader.py" "${INSTALL_DIR}/sms_common.py"
  PYTHON_BIN=""
  for cand in "$(command -v python3.14 2>/dev/null)" "$(command -v python3 2>/dev/null)"; do
    if [ -n "${cand}" ] && [ -x "${cand}" ]; then PYTHON_BIN="${cand}"; break; fi
  done
  if [ -z "${PYTHON_BIN}" ]; then
    echo "ERROR: python3 not found. Install Python 3 (e.g. 'brew install python@3.14')."
    exit 1
  fi
  PYTHON_REAL="$(python3 -c 'import os,sys;print(os.path.realpath(sys.executable))' 2>/dev/null || echo "${PYTHON_BIN}")"
  HOST_EXEC="${INSTALL_DIR}/sms_host.py"
  READER_ARGS=("${PYTHON_REAL}" "${INSTALL_DIR}/sms_reader.py")
  FDA_TARGET="${PYTHON_REAL}"
fi
echo "  Host executable: ${HOST_EXEC}"

# Register the native-messaging manifest for Firefox.
mkdir -p "${NM_DIR}"
cat > "${NM_MANIFEST}" <<EOF
{
  "name": "${HOST_NAME}",
  "description": "SMS Code Filler: fill phone verification codes into Firefox",
  "path": "${HOST_EXEC}",
  "type": "stdio",
  "allowed_extensions": ["${EXT_ID}"]
}
EOF
echo "  Manifest written to: ${NM_MANIFEST}"

# Install the launchd agent (the FDA-granted reader).
READER_XML=""
for a in "${READER_ARGS[@]}"; do
  READER_XML+=$'    <string>'"${a}"$'</string>\n'
done
mkdir -p "${LA_DIR}"
cat > "${LA_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${SESSION_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
${READER_XML}  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>${INSTALL_DIR}/reader.out</string>
  <key>StandardErrorPath</key><string>${INSTALL_DIR}/reader.err</string>
</dict>
</plist>
EOF
echo "  LaunchAgent written to: ${LA_PLIST}"

# (Re)load the agent.
UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}/${SESSION_LABEL}" >/dev/null 2>&1 || true
if launchctl bootstrap "gui/${UID_NUM}" "${LA_PLIST}" >/dev/null 2>&1; then
  echo "  LaunchAgent loaded."
elif launchctl load "${LA_PLIST}" >/dev/null 2>&1; then
  echo "  LaunchAgent loaded (legacy)."
else
  echo "  WARN: could not load the LaunchAgent automatically."
  echo "        Reload it with:  launchctl bootstrap gui/${UID_NUM} \"${LA_PLIST}\""
fi

# Give permission hints.
echo
echo "==> Grant Full Disk Access to the READER ONLY (this reads Messages):"
echo
echo "     System Settings > Privacy & Security > Full Disk Access > +"
echo "     Cmd+Shift+G and paste:"
echo "       ${FDA_TARGET}"
echo "     Toggle it ON."
echo
echo "     Firefox, sqlite3, and Python are NOT needed: the add-on's host reads"
echo "     codes.json (a normal user file), so it needs no Full Disk Access, and"
echo "     the sqlite3 fallback is never used. (If you installed the SOURCE"
echo "     version instead of the compiled binary, grant the Python interpreter"
echo "     that runs the reader.)"
echo
echo "     Then relaunch the reader:  launchctl kickstart gui/$(id -u)/${SESSION_LABEL}"
echo "     or just log out and back in."
echo
echo "==> Verify the cache is being written:"
echo "     cat '${INSTALL_DIR}/codes.json'   (after a few seconds — should list codes)"
echo "     tail '${INSTALL_DIR}/reader.log'  (should show no 'error:' lines once FDA is granted)"
echo
echo "Done."
