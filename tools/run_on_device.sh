#!/usr/bin/env bash
# Build Headway (an optimised Release build: the timetable loads several times faster than in a Debug build) and
# install it on a connected iPhone or iPad.
#
#   tools/run_on_device.sh --list        # the paired devices, nothing is built
#   tools/run_on_device.sh               # the one paired device; with several, it stops and lists them
#   tools/run_on_device.sh "iPad"        # one device, by its name (the whole name, else a part of it) or by its id
#
# Needs Config/Local.xcconfig with your DEVELOPMENT_TEAM (see docs/run-on-iphone.md). Xcode creates the signing
# certificate and provisioning profile itself (-allowProvisioningUpdates), so you must be signed in to your Apple ID in
# Xcode > Settings > Accounts once.
set -euo pipefail
cd "$(dirname "$0")/.."

# Prints "id|name|kind|state" of the device to use, or the list of devices with --list. A real device is any device that is
# not a simulator (simulators say "simulated"; real ones leave it empty or say "physical"). It never picks one by itself
# when there are several: an iPhone and an iPad paired with the same Mac must not be mixed up.
choose_device() {
  local list wanted="$1"
  list="$(mktemp)"
  xcrun devicectl list devices --json-output "$list" >/dev/null 2>&1 || true
  python3 - "$list" "$wanted" <<'PY'
import json, sys

path, wanted = sys.argv[1], sys.argv[2]
try:
    devices = json.load(open(path))["result"]["devices"]
except Exception:
    devices = []
real = [d for d in devices if d["hardwareProperties"].get("reality") != "simulated"]

def fields(d):
    hw, props, conn = d["hardwareProperties"], d["deviceProperties"], d["connectionProperties"]
    return hw["udid"], props.get("name", "device"), hw.get("deviceType", "device"), conn.get("tunnelState", "")

def show(items):
    for d in items:
        udid, name, kind, state = fields(d)
        print(f"  {name}  ({kind}, {state or 'paired'})  id {udid}", file=sys.stderr)

if wanted == "--list":
    show(real) if real else print("No device is paired with this Mac.", file=sys.stderr)
    sys.exit(0 if real else 1)
if not real:
    print("This Mac has not paired with any iPhone or iPad. Connect it with a cable, unlock it, and tap Trust.", file=sys.stderr)
    sys.exit(1)
if wanted:
    key = wanted.lower()
    chosen = [d for d in real if key in (fields(d)[0].lower(), d.get("identifier", "").lower(), fields(d)[1].lower())]
    if not chosen:
        chosen = [d for d in real if key in fields(d)[1].lower()]
    if len(chosen) != 1:
        print(f'"{wanted}" matches {"no device" if not chosen else "several devices"}. Paired devices:', file=sys.stderr)
        show(real)
        sys.exit(1)
elif len(real) == 1:
    chosen = real
else:
    print("Several devices are paired. Say which one (its name or id) and run this again:", file=sys.stderr)
    show(real)
    sys.exit(1)
print("|".join(fields(chosen[0])))
PY
  local status=$?
  rm -f "$list"
  return $status
}

if [ "${1:-}" = "--list" ]; then
  choose_device "--list"
  exit $?
fi

[ -f Config/Local.xcconfig ] || { echo "Missing Config/Local.xcconfig (see Config/Local.xcconfig.example)"; exit 1; }
[ -f data/maps/madison.pmtiles ] || tools/fetch_basemap.sh
[ -f data/seed/mmt_gtfs.zip ] || tools/fetch_timetable.sh
[ -f data/punctuality/punctuality.json ] || tools/build_punctuality.sh
xcodegen generate >/dev/null

FOUND=$(choose_device "${1:-}") || exit 1
DEVICE=$(echo "$FOUND" | cut -d'|' -f1)
NAME=$(echo "$FOUND" | cut -d'|' -f2)
KIND=$(echo "$FOUND" | cut -d'|' -f3)
# A paired device often reports "disconnected" until something connects to it (that is normal for wireless use), so
# try to reach it instead of trusting the state.
if ! xcrun devicectl device info details --device "$DEVICE" >/dev/null 2>&1; then
  echo "$NAME is paired but cannot be reached. Plug it in with the cable (or enable \"Connect via network\" in Xcode >"
  echo "Window > Devices and Simulators), unlock it, and run this again."
  [ "${CHECK_ONLY:-}" = "1" ] || exit 1
fi
echo "Found $NAME ($KIND)"
[ "${CHECK_ONLY:-}" = "1" ] && exit 0
echo "Device: $DEVICE"

LOG="build/device-build.log"
mkdir -p build
if ! xcodebuild -project Headway.xcodeproj -scheme Headway -configuration Release \
  -destination "id=$DEVICE" -derivedDataPath build/Device -allowProvisioningUpdates build > "$LOG" 2>&1; then
  echo "Build failed. Errors:"
  grep -E "error:" "$LOG" | sort -u | head -n 10
  if grep -q "needs to be unlocked" "$LOG"; then
    echo "The $KIND is locked. Unlock it, keep the screen on, and run this again."
  fi
  echo "(full log: $LOG; the first build after adding an Apple ID sometimes fails while Xcode creates the signing profile, so try once more)"
  exit 1
fi
APP="build/Device/Build/Products/Release-iphoneos/Headway.app"
xcrun devicectl device install app --device "$DEVICE" "$APP"
if ! xcrun devicectl device process launch --device "$DEVICE" dev.kosuke.headway; then
  echo
  echo "Installed, but it could not start. On the first install the $KIND must trust you as a developer:"
  echo "  Settings > General > VPN & Device Management > your Apple ID > Trust."
  echo "Then open Headway from the Home screen."
fi
