#!/usr/bin/env bash
# Module: run-tests.sh
# Author: <проект>
# Description: Собирает тест-проект через S1 (build.sh) и запускает свежий
#              .exe с таймаутом и stdin из /dev/null; печатает счётчики.
# History: 2026-02-14: Created
#
# Usage: bash scripts/run-tests.sh <Unit|Int|all> [--no-build] [--allow-stale]
#        TEST_TIMEOUT=60 — секунды на один exe.
# Output: BUILD|..., TEST|<unit|int>|run=N|errors=N|failures=N|exit=N|exe=...|log=...
#         RESULT|test-<unit|int>|pass|fail|skipped|...
#         SUMMARY|pass=N|fail=N|skipped=N
# Exit: 0 — все pass; 1 — есть fail; 2 — ничего не запущено; 64 — аргументы.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')"
[ -z "$ROOT" ] && ROOT="$(pwd)"
cd "$ROOT" 2>/dev/null || { echo "RESULT|error|fail|нет каталога $ROOT"; exit 2; }
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$SKILL_DIR/../pascal-build-probe/scripts/build.sh"
TIMEOUT="${TEST_TIMEOUT:-60}"
DO_BUILD=1
ALLOW_STALE=0
TARGETS=""

usage() {
  echo "Usage: bash scripts/run-tests.sh <Unit|Int|all> [--no-build] [--allow-stale]"
  echo "  Unit — test/pkg/lz/Test.lpi; Int — TestInt.lpi; all — оба."
  echo "  --no-build     не вызывать build.sh (только запуск готового exe)."
  echo "  --allow-stale  разрешить exe старше исходников."
  echo "  TEST_TIMEOUT=${TIMEOUT} (секунды)."
}

for a in "$@"; do
  case "$a" in
    Unit|Int|all) TARGETS="$TARGETS $a" ;;
    --no-build) DO_BUILD=0 ;;
    --allow-stale) ALLOW_STALE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR|bad-arg|$a" >&2; usage >&2; exit 64 ;;
  esac
done
[ -z "$TARGETS" ] && { usage >&2; exit 64; }

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="$ROOT/out/probe"
mkdir -p "$LOGDIR" || { echo "RESULT|error|fail|не создать $LOGDIR"; exit 2; }

PASS_N=0; FAIL_N=0; SKIP_N=0

finish() { # finish <label> <pass|fail|skipped> <detail>
  local label="$1" status="$2" detail="${3:-}"
  echo "RESULT|test-$label|$status|$detail"
  case "$status" in
    pass) PASS_N=$((PASS_N + 1)) ;;
    fail) FAIL_N=$((FAIL_N + 1)) ;;
    skipped) SKIP_N=$((SKIP_N + 1)) ;;
  esac
}

newest_exe() { # newest_exe <name.exe>
  find "$ROOT/test/out" -type f -name "$1" -exec stat -c '%Y %n' {} + 2>/dev/null \
    | sort -nr | head -1 | cut -d' ' -f2-
}

newest_source() {
  find "$ROOT/test/src" "$ROOT/lib/src" "$ROOT/test/pkg/lz" -type f \
    \( -name '*.pas' -o -name '*.lpr' -o -name '*.lpi' -o -name '*.inc' \) \
    ! -path '*/backup/*' \
    -exec stat -c '%Y %n' {} + 2>/dev/null | sort -nr | head -1
}

run_one() { # run_one <Unit|Int>
  local mode="$1" label build_target lpi exe_name exe src_line src_mtime exe_mtime
  local log rc run errors failures
  if [ "$mode" = "Unit" ]; then
    label="unit"; build_target="tests"; lpi="test/pkg/lz/Test.lpi"; exe_name="Test.exe"
  else
    label="int";  build_target="tests-int"; lpi="test/pkg/lz/TestInt.lpi"; exe_name="TestInt.exe"
  fi

  if [ "$DO_BUILD" = 1 ]; then
    local bout brc
    bout="$(bash "$BUILD" "$build_target" 2>&1)"; brc=$?
    printf '%s\n' "$bout" | grep -E '^(BUILD|RESULT|SUMMARY)\|' || true
    if ! printf '%s\n' "$bout" | grep -q "^RESULT|$build_target|ok|"; then
      echo "TEST|$label|build-not-ok|exit=$brc"
      finish "$label" skipped "build-not-ok|exit=$brc"
      return
    fi
  fi

  exe="$(newest_exe "$exe_name")"
  if [ -z "$exe" ]; then
    echo "TEST|$label|no-exe|$exe_name"
    finish "$label" skipped "no-exe"
    return
  fi

  src_line="$(newest_source)"
  src_mtime="${src_line%% *}"; src_line="${src_line#* }"
  exe_mtime="$(mtime "$exe")"
  if [ "$exe_mtime" -lt "$src_mtime" ] && [ "$ALLOW_STALE" != 1 ]; then
    echo "WARN|stale-exe|$exe|exe=$(date -d "@$exe_mtime" '+%F %T' 2>/dev/null || echo "$exe_mtime")|src=$src_line"
    finish "$label" skipped "stale-exe|$exe"
    return
  fi

  log="$LOGDIR/test-$label-$STAMP.log"
  rm -f "$(dirname "$exe")/test.log" "$(dirname "$exe")/async.log"
  ( cd "$(dirname "$exe")" && timeout "$TIMEOUT" "./$(basename "$exe")" < /dev/null ) >"$log" 2>&1
  rc=$?

  run="$(sed -n 's/^Number of run tests:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$log" | head -1)"
  errors="$(sed -n 's/^Number of errors:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$log" | head -1)"
  failures="$(sed -n 's/^Number of failures:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$log" | head -1)"
  echo "TEST|$label|run=${run:-?}|errors=${errors:-?}|failures=${failures:-?}|exit=$rc|exe=$exe|log=$log"

  if [ "$rc" = 124 ]; then
    finish "$label" fail "timeout=${TIMEOUT}s|$log"
  elif [ -z "$run" ] || [ -z "$errors" ] || [ -z "$failures" ]; then
    echo "ERROR|no-summary|$log"
    tail -20 "$log" 2>/dev/null || true
    finish "$label" fail "no-summary|exit=$rc|$log"
  elif [ "$run" -eq 0 ]; then
    finish "$label" fail "no-tests-run|$log"
  elif [ "$rc" -eq 0 ] && [ "$errors" -eq 0 ] && [ "$failures" -eq 0 ]; then
    finish "$label" pass "run=$run|$log"
  else
    grep -E 'Failed:|Exception|Number of (errors|failures)' "$log" | head -10 || true
    finish "$label" fail "run=$run|errors=$errors|failures=$failures|exit=$rc|$log"
  fi
}

for t in $TARGETS; do
  case "$t" in
    all) run_one Unit; run_one Int ;;
    Unit|Int) run_one "$t" ;;
  esac
done

echo "SUMMARY|pass=$PASS_N|fail=$FAIL_N|skipped=$SKIP_N"
[ "$FAIL_N" -gt 0 ] && exit 1
[ "$PASS_N" -eq 0 ] && exit 2
exit 0
