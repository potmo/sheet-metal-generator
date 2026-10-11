#!/bin/bash
# Golden-output harness for sheet-metal-generator.
#
#   ./golden.sh record   build + regenerate golden/ from the current CanvasRender code
#   ./golden.sh verify   build + generate into a temp dir + diff -r against golden/ (non-zero exit on mismatch)
#   ./golden.sh record --quick / verify --quick
#                        fast subset (~1 min) against golden-quick/: "DXF all" renders only 2 boxes,
#                        baseplate export skipped. Use while iterating, run the full verify at the end.
#
# Builds the `sheet-metal-golden` CLI with the Xcode beta 27 toolchain (the default swift.org 6.2
# toolchain on PATH crashes on this code). Release config (+ -enable-testing for @testable import of the
# lib), because the DXF "baseplate"/"all" exports are very slow in debug.
#
# Locale is pinned with `-AppleLocale en_SE` (the machine's own locale): CanvasRender's Double.toFixed
# uses a locale-dependent NumberFormatter (e.g. sv_SE emits U+2212 as minus sign in the DXF scripts).
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
GOLDEN="$ROOT/golden"
QUICK_ARGS=()
if [ "${2:-}" = "--quick" ]; then
    GOLDEN="$ROOT/golden-quick"
    QUICK_ARGS=(--quick)
fi

export DEVELOPER_DIR=/Applications/Xcode-beta-27.app/Contents/Developer
X="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin"
BUILD_FLAGS=(-c release -Xswiftc -enable-testing)

build() {
    echo "building sheet-metal-golden..." >&2
    "$X/swift-build" "${BUILD_FLAGS[@]}" --product sheet-metal-golden >&2
    BIN="$("$X/swift-build" "${BUILD_FLAGS[@]}" --show-bin-path)/sheet-metal-golden"
    [ -x "$BIN" ] || { echo "binary not found: $BIN" >&2; exit 1; }
}

generate() {
    local out="$1"
    rm -rf "$out"
    mkdir -p "$out"
    local bindir pids=() names=() failed=0
    bindir="$(mktemp -d "${TMPDIR:-/tmp}/sheet-metal-golden-bin.XXXXXX")"
    echo "generating into $out ..." >&2
    # One process per scenario, run in parallel. Each runs from a copy of the binary named
    # sheet-metal-golden-<scenario> so each process has its own (wiped) UserDefaults domain.
    for scenario in $("$BIN" --list-scenarios); do
        cp "$BIN" "$bindir/sheet-metal-golden-$scenario"
        # library print() output (CodeBlocks etc.) is part of the golden as stdout-<scenario>.txt
        LC_ALL=en_US.UTF-8 "$bindir/sheet-metal-golden-$scenario" -AppleLocale en_SE --only "$scenario" ${QUICK_ARGS[@]+"${QUICK_ARGS[@]}"} --out "$out" \
            > "$out/stdout-$scenario.txt" 2> "$bindir/$scenario.log" &
        pids+=($!)
        names+=("$scenario")
    done
    for i in "${!pids[@]}"; do
        if ! wait "${pids[$i]}"; then
            echo "scenario ${names[$i]} FAILED:" >&2
            tail -20 "$bindir/${names[$i]}.log" >&2
            failed=1
        fi
    done
    rm -rf "$bindir"
    # remove the tool's own (already wiped) defaults domains; never touches any other domain
    for scenario in $("$BIN" --list-scenarios) ""; do
        defaults delete "sheet-metal-golden${scenario:+-$scenario}" >/dev/null 2>&1 || true
        rm -f "$HOME/Library/Preferences/sheet-metal-golden${scenario:+-$scenario}.plist"
    done
    [ "$failed" = 0 ] || exit 1
}

summary() {
    local dir="$1"
    echo "$(find "$dir" -type f | wc -l | tr -d ' ') files, $(du -sh "$dir" | cut -f1)"
}

case "${1:-}" in
record)
    build
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/sheet-metal-golden.XXXXXX")"
    generate "$tmp/out"
    # The project lives in a synced folder: deleting and recreating golden files makes the sync service
    # create "name 2.ext" conflict copies. So record into a temp dir and update golden/ in place with rsync.
    mkdir -p "$GOLDEN"
    rsync -a --delete --checksum "$tmp/out/" "$GOLDEN/"
    rm -rf "$tmp"
    echo "recorded $(basename "$GOLDEN")/: $(summary "$GOLDEN")"
    ;;
verify)
    [ -d "$GOLDEN" ] || { echo "no $(basename "$GOLDEN")/ directory, run ./golden.sh record ${2:-} first" >&2; exit 1; }
    build
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/sheet-metal-golden.XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT
    generate "$tmp/out"
    if diff -rq "$GOLDEN" "$tmp/out" > "$tmp/diff.txt"; then
        echo "verify OK: output identical to $(basename "$GOLDEN")/ ($(summary "$GOLDEN"))"
    else
        echo "verify FAILED: $(wc -l < "$tmp/diff.txt" | tr -d ' ') differing/missing files:"
        head -40 "$tmp/diff.txt"
        first="$(grep '^Files ' "$tmp/diff.txt" | head -1 | sed -E 's/^Files (.*) and (.*) differ$/\1\t\2/')"
        if [ -n "$first" ]; then
            a="$(cut -f1 <<< "$first")"; b="$(cut -f2 <<< "$first")"
            echo "--- first differing file (first 30 diff lines): ${a#$GOLDEN/}"
            diff "$a" "$b" | head -30 || true
        fi
        exit 1
    fi
    ;;
*)
    echo "usage: $0 record|verify [--quick]" >&2
    exit 2
    ;;
esac
