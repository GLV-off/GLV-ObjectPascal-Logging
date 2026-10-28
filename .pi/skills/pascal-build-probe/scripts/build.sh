#!/usr/bin/env bash
# Module: build.sh
# Author: <проект>
# Description: Сборка выбранных точек проекта через lazbuild с фолбэком на fpc.
#              Пишет полный лог в out/probe/<target>-<timestamp>.log.
# History: 2026-02-14: Created
#
# Usage: bash scripts/build.sh <target> [<target> ...]
#        targets: lib-v2 | lib-v1-ct | tests | tests-int | demo | all
#        env:     BUILD_MODE=Debug (по умолчанию; Release — для проектов с режимом)
#                 FPC=/path/to/fpc        (переопределить компилятор из probe.sh)
#                 LAZBUILD=/path/to/lazbuild  (LAZBUILD=off — принудительный фолбэк на fpc)
#
# Output: строки probe.sh, затем по цели
#   RESULT|<target>|ok|fail|skipped|<log|причина>
#   SUMMARY|ok=N|fail=N|skipped=N|logs=out/probe
#
# Exit: 0 — все цели ok; 1 — была цель fail; 2 — ничего не собрано (все skipped);
#       64 — нет аргументов / неизвестная цель.
# Сборка не запускалась ⇒ результат «skipped»/«не проверено», никогда не «ok».
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')"
[ -z "$ROOT" ] && ROOT="$(pwd)"
cd "$ROOT" 2>/dev/null || { echo "RESULT|error|fail|нет каталога $ROOT"; exit 2; }
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGETS_ALL="lib-v2 lib-v1-ct tests tests-int demo"
BUILD_MODE="${BUILD_MODE:-Debug}"

usage() {
  echo "Usage: bash scripts/build.sh <target> [<target> ...]"
  echo "Targets:"
  echo "  lib-v2      glv_log_contract.lpk + glv_log_def_engine.lpk (Lazarus, v2)"
  echo "  lib-v1-ct   компиляция фасада GlvLog.pas (CodeTyphon-пакет .ctpkg не собирается lazbuild)"
  echo "  tests       test/pkg/lz/Test.lpi    (unit-тесты)"
  echo "  tests-int   test/pkg/lz/TestInt.lpi (интеграционные тесты)"
  echo "  demo        demos/simple/pkg/lz/Demo.lpi"
  echo "  all         все цели по порядку"
  echo "Env: BUILD_MODE=${BUILD_MODE} (Debug|Release), FPC=..., LAZBUILD=..."
}

if [ "$#" = 0 ]; then usage; exit 64; fi

for t in "$@"; do
  case " $TARGETS_ALL all " in
    *" $t "*) ;;
    *) echo "RESULT|$t|skipped|unknown target"; usage >&2; exit 64 ;;
  esac
done

STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="$ROOT/out/probe"
mkdir -p "$LOGDIR" || { echo "RESULT|error|fail|не создать $LOGDIR"; exit 2; }

# --- тулчейн: единственный источник истины — probe.sh -------------------------
PROBE_OUT="$(bash "$SKILL_DIR/scripts/probe.sh" "$ROOT")"
PROBE_RC=$?
printf '%s\n' "$PROBE_OUT"
echo "PROBE|exit=$PROBE_RC"

FPC_BIN="${FPC:-$(printf '%s\n' "$PROBE_OUT" | awk -F'|' '$1=="TOOL" && $2 ~ /^fpc-/ && $3=="ok" {print $4; exit}')}"
if [ "${LAZBUILD:-}" = "off" ]; then
  LAZBUILD_BIN=""   # принудительный фолбэк на fpc (для проверки ветки)
else
  LAZBUILD_BIN="${LAZBUILD:-$(printf '%s\n' "$PROBE_OUT" | awk -F'|' '$1=="TOOL" && $2=="lazbuild" && $3=="ok" {print $4; exit}')}"
fi

[ -n "$FPC_BIN" ] && echo "BUILD|compiler|$FPC_BIN" || echo "BUILD|compiler|absent"
[ -n "$LAZBUILD_BIN" ] && echo "BUILD|lazbuild|$LAZBUILD_BIN" || echo "BUILD|lazbuild|absent"

OK_N=0; FAIL_N=0; SKIP_N=0

run_log() { # run_log <log> <cmd...>
  local log="$1"; shift
  { printf '\n### %s\n### CMD: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; "$@"; } >>"$log" 2>&1
}

finish() { # finish <target> <ok|fail|skipped> <detail>
  local target="$1" status="$2" detail="${3:-}"
  echo "RESULT|$target|$status|$detail"
  case "$status" in
    ok) OK_N=$((OK_N + 1)) ;;
    fail) FAIL_N=$((FAIL_N + 1)) ;;
    skipped) SKIP_N=$((SKIP_N + 1)) ;;
  esac
}

fpc_units_dir() { mkdir -p "$LOGDIR/units-$1" && wpath "$LOGDIR/units-$1"; }

# wpath — путь в родном для FPC виде (git-bash: C:\dev\...). FPC 3.2.2/Windows
# не понимает "C:/..." в -Fu/-Fi/-FU: путь склеивается с текущим диском.
wpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

# --- цели ---------------------------------------------------------------------
build_lib_v2() {
  local log="$LOGDIR/lib-v2-$STAMP.log"
  : >"$log"
  if [ -n "$LAZBUILD_BIN" ]; then
    rc=0
    run_log "$log" "$LAZBUILD_BIN" lib/pkg/lz/glv_log_contract.lpk || rc=1
    [ "$rc" = 0 ] && { run_log "$log" "$LAZBUILD_BIN" lib/pkg/lz/glv_log_def_engine.lpk || rc=1; }
    if [ "$rc" = 0 ]; then finish lib-v2 ok "$log"; else finish lib-v2 fail "$log"; fi
    return
  fi
  if [ -z "$FPC_BIN" ]; then finish lib-v2 skipped "нет ни lazbuild, ни fpc"; return; fi
  local u; u="$(fpc_units_dir lib-v2)"
  local f rc=0
  for f in GLV.Log.pas GLV.Log.ConsoleEngine.pas GLV.Log.SyncFileEngine.pas; do
    run_log "$log" "$FPC_BIN" -Mdelphi -Fu"$(wpath "$ROOT/lib/src")" \
      -Fi"$(wpath "$ROOT/lib/src")" -FU"$u" "$(wpath "$ROOT/lib/src/$f")" || rc=1
  done
  if [ "$rc" = 0 ]; then finish lib-v2 ok "$log"; else finish lib-v2 fail "$log"; fi
}

build_lib_v1_ct() {
  local log="$LOGDIR/lib-v1-ct-$STAMP.log"
  : >"$log"
  if [ -z "$FPC_BIN" ]; then finish lib-v1-ct skipped "fpc не найден"; return; fi
  local u; u="$(fpc_units_dir lib-v1-ct)"
  if run_log "$log" "$FPC_BIN" -Mdelphi -Fu"$(wpath "$ROOT/lib/src")" \
       -Fi"$(wpath "$ROOT/lib/src")" -FU"$u" "$(wpath "$ROOT/lib/src/GlvLog.pas")"; then
    finish lib-v1-ct ok "$log"
  else
    finish lib-v1-ct fail "$log"
  fi
}

build_project() { # build_project <target> <lpi> <lpr>
  local target="$1" lpi="$2" lpr="$3"
  local log="$LOGDIR/$target-$STAMP.log"
  : >"$log"
  if [ -n "$LAZBUILD_BIN" ]; then
    if run_log "$log" "$LAZBUILD_BIN" --build-mode="$BUILD_MODE" "$lpi"; then
      finish "$target" ok "$log"
    else
      finish "$target" fail "$log"
    fi
    return
  fi
  if [ -z "$FPC_BIN" ]; then finish "$target" skipped "нет ни lazbuild, ни fpc"; return; fi
  local u; u="$(fpc_units_dir "$target")"
  local ed; ed="$LOGDIR/bin-$target"; mkdir -p "$ed"
  if run_log "$log" "$FPC_BIN" -Mdelphi \
       -Fu"$(wpath "$ROOT/lib/src")" -Fu"$(wpath "$ROOT/test/src")" \
       -Fu"$(wpath "$ROOT/../pas_TestingWrapper/Src")" \
       -Fi"$(wpath "$ROOT/lib/src")" -Fi"$(wpath "$ROOT/test/src")" \
       -FU"$u" -FE"$(wpath "$ed")" "$(wpath "$lpr")"; then
    finish "$target" ok "$log"
  else
    finish "$target" fail "$log"
  fi
}

for t in "$@"; do
  case "$t" in
    all) for x in $TARGETS_ALL; do
           case "$x" in
             lib-v2) build_lib_v2 ;;
             lib-v1-ct) build_lib_v1_ct ;;
             tests) build_project tests test/pkg/lz/Test.lpi test/pkg/lz/Test.lpr ;;
             tests-int) build_project tests-int test/pkg/lz/TestInt.lpi test/pkg/lz/TestInt.lpr ;;
             demo) build_project demo demos/simple/pkg/lz/Demo.lpi demos/simple/pkg/lz/Demo.lpr ;;
           esac
         done ;;
    lib-v2) build_lib_v2 ;;
    lib-v1-ct) build_lib_v1_ct ;;
    tests) build_project tests test/pkg/lz/Test.lpi test/pkg/lz/Test.lpr ;;
    tests-int) build_project tests-int test/pkg/lz/TestInt.lpi test/pkg/lz/TestInt.lpr ;;
    demo) build_project demo demos/simple/pkg/lz/Demo.lpi demos/simple/pkg/lz/Demo.lpr ;;
  esac
done

echo "SUMMARY|ok=$OK_N|fail=$FAIL_N|skipped=$SKIP_N|logs=out/probe"

[ "$FAIL_N" -gt 0 ] && exit 1
[ "$OK_N" -eq 0 ] && exit 2
exit 0
