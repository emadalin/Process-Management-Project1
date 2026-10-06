#!/bin/bash
#
# One command for every team member. It does two of Member 1's collection jobs
# at once: it proves the package builds and runs on your Mac, and it prints the
# machine-details row for you to paste back.
#
#   cd project2 && ./verify.sh
#
# Send Sarah everything between the two ===== lines.

set -u
cd "$(dirname "$0")"

fail=0
step() { printf '%-42s' "$1"; }
ok()   { echo "ok"; }
bad()  { echo "FAILED"; fail=1; }

echo "Verifying PlaylistStreamer..."
echo

step "swift build"
if swift build >/tmp/plstream-build.log 2>&1; then ok; else bad; fi

step "swift build -c release"
if swift build -c release >>/tmp/plstream-build.log 2>&1; then ok; else bad; fi

# Each mode must exit 0. The comparison is still a stub, so it is reported but
# not counted as a failure until Georgia's demo lands.
for mode in stack heap buffer; do
    step "swift run PlaylistStreamer $mode"
    if swift run -q PlaylistStreamer "$mode" >/tmp/plstream-$mode.log 2>&1; then ok; else bad; fi
done

step "swift run PlaylistStreamer compare"
out=$(swift run -q PlaylistStreamer compare 2>&1 || true)
case "$out" in
    *"not implemented yet"*) echo "stub (expected for now)" ;;
    *)                       echo "implemented" ;;
esac

echo
if [ "$fail" -ne 0 ]; then
    echo "Something failed. Send Sarah /tmp/plstream-build.log along with the row below."
else
    echo "All good."
fi

# ---- the machine-details row -------------------------------------------------

os=$(sw_vers -productVersion)
build=$(sw_vers -buildVersion)
arch=$(uname -m)
chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
ram=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
page=$(pagesize)
swiftv=$(swift --version 2>&1 | sed -n 's/.*Apple Swift version \([^ ]*\) (\(swiftlang-[^ )]*\).*/\1 (\2)/p')
[ -z "$swiftv" ] && swiftv=$(swift --version 2>&1 | head -1)
xc=$(xcodebuild -version 2>/dev/null | tr '\n' ' ' | sed -n 's/Xcode \([^ ]*\) Build version \([^ ]*\).*/\1 (\2)/p')
[ -z "$xc" ] && xc="not installed"

echo
echo "====================== paste this to Sarah ======================"
echo "| YOUR NAME (member #) | $os ($build) | $chip ($arch) | $ram GB | $page B | $swiftv | $xc |"
echo "================================================================="
