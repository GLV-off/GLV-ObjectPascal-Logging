#!/usr/bin/env bash
# Module: probe.sh
# Author: <проект>
# Description: Детект Pascal-тулчейна (FPC/Lazarus/Delphi) и зависимостей тестов.
#              Ничего не собирает; отсутствие тулчейна — это результат.
# History: 2026-02-14: Created
#
# Usage: bash scripts/probe.sh [repo-root]
# Output: TOOL|..., ENV|..., WARN|..., DEP|..., SUMMARY|... (см. SKILL.md)
# Exit:   0 = FPC+lazbuild+tests-dep; 2 = частично; 3 = нет ни FPC, ни lazbuild.
set -uo pipefail

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')"
  [ -z "$ROOT" ] && ROOT="$(pwd)"
fi
cd "$ROOT" 2>/dev/null || { echo "TOOL|error|no-root|$ROOT"; exit 1; }

TMPD="${TMPDIR:-/tmp}"
CANDS="$(mktemp "$TMPD/glv-probe-cands.XXXXXX" 2>/dev/null || echo "$TMPD/glv-probe-cands.$$")"
FPCS="$(mktemp "$TMPD/glv-probe-fpcs.XXXXXX" 2>/dev/null || echo "$TMPD/glv-probe-fpcs.$$")"
trap 'rm -f "$CANDS" "$FPCS" "$FPCS.d"' EXIT
: >"$CANDS"; : >"$FPCS"

# norm — путь в виде C:/dev/... без '..' и обратных слэшей.
norm() {
  local p="${1//\\//}" d b
  d="$(dirname "$p")"; b="$(basename "$p")"
  if [ -d "$d" ]; then
    printf '%s/%s' "$(cd "$d" 2>/dev/null && { pwd -W 2>/dev/null || pwd; })" "$b"
  else
    printf '%s' "$p"
  fi
}

add() { local p="${2:-}"; [ -n "$p" ] && [ -f "$p" ] && printf '%s|%s\n' "$1" "$p" >>"$CANDS"; return 0; }
add_glob() { local pr="$1" f; shift; for f in "$@"; do add "$pr" "$f"; done; }

# --- 1. кандидаты: PATH -> $PP -> $FPCDIR/$LAZARUSDIR -> типовые корни ----------
add 0 "$(command -v fpc 2>/dev/null || true)"
add 0 "$(command -v fpc.exe 2>/dev/null || true)"
add 1 "${PP:-}"
if [ -n "${LAZARUSDIR:-}" ]; then
  add_glob 2 "$LAZARUSDIR"/fpc/*/bin/*/fpc.exe "$LAZARUSDIR"/fpc/*/bin/*/ppc*.exe
fi
if [ -n "${FPCDIR:-}" ]; then
  add_glob 2 "$FPCDIR"/bin/*/fpc.exe "$FPCDIR"/../bin/*/fpc.exe \
              "$FPCDIR"/bin/*/ppc*.exe "$FPCDIR"/../bin/*/ppc*.exe
fi
for root in "C:/dev/tools/lazarus" "C:/dev/tools/fpcdelux" "C:/lazarus" "C:/FPC" \
            "/usr" "/usr/lib/fpc" "/opt/fpc" "/usr/local"
do
  add_glob 3 "$root"/fpc/*/bin/*/fpc.exe "$root"/fpc/*/bin/*/ppc*.exe \
              "$root"/fpc/bin/*/fpc.exe "$root"/fpc/bin/*/ppc*.exe \
              "$root"/bin/fpc "$root"/bin/fpc.exe "$root"/lib/fpc/*/ppc*
done

# --- 2. опрос: существование + версия + целевой CPU ---------------------------
while IFS='|' read -r pr p; do
  [ -x "$p" ] || continue
  ver="$("$p" -iV 2>/dev/null | tr -d '\r\n' | awk '{print $1; exit}')"
  [ -n "$ver" ] || continue
  cpu="$("$p" -iTP 2>/dev/null | tr -d '\r\n' | awk '{print $1; exit}')"
  printf '%s|%s|%s|%s\n' "${cpu:-unknown}" "$(norm "$p")" "$ver" "$pr" >>"$FPCS"
done < <(sort -t'|' -k1,1n "$CANDS")
awk -F'|' '!seen[$2]++' "$FPCS" | sort -t'|' -k1,1 -k4,4n -k2,2 >"$FPCS.d" && mv "$FPCS.d" "$FPCS"

fpc_label() { case "$1" in i386) echo fpc-i386 ;; x86_64) echo fpc-x64 ;; *) echo "fpc-$1" ;; esac; }
FPC_COUNT=0; CHOSEN=""; SEEN_CPUS=""; SEEN_DIRS=""
if [ -s "$FPCS" ]; then
  while IFS='|' read -r cpu path ver pr; do
    dir="$(dirname "$path")"
    case " $SEEN_DIRS " in *" $cpu:$dir "*) continue ;; esac   # fpc.exe и ppc*.exe в одном bin
    SEEN_DIRS="$SEEN_DIRS $cpu:$dir"
    case " $SEEN_CPUS " in *" $cpu "*) continue ;; esac         # только первый на CPU
    SEEN_CPUS="$SEEN_CPUS $cpu"
    echo "TOOL|$(fpc_label "$cpu")|ok|$path|$ver"
    FPC_COUNT=$((FPC_COUNT + 1)); CHOSEN="$CHOSEN $path"
  done <"$FPCS"
fi
[ "$FPC_COUNT" = 0 ] && echo "TOOL|fpc|absent|"

# --- 3. окружение -------------------------------------------------------------
env_check() {
  if [ -z "${2:-}" ]; then echo "ENV|$1|unset|"
  elif [ -e "$2" ]; then echo "ENV|$1|ok|$(norm "$2")"
  else echo "ENV|$1|stale|$(norm "$2")"; fi
}
env_check PP "${PP:-}"; env_check FPCDIR "${FPCDIR:-}"; env_check LAZARUSDIR "${LAZARUSDIR:-}"

# --- 4. lazbuild --------------------------------------------------------------
LAZBUILD_OK=0
for c in "$(command -v lazbuild 2>/dev/null || true)" \
         "${LAZARUSDIR:-}/lazbuild.exe" "${LAZARUSDIR:-}/lazbuild" \
         "C:/dev/tools/lazarus/lazbuild.exe" "C:/dev/tools/fpcdelux/lazarus/lazbuild.exe"
do
  [ -n "$c" ] && [ -x "$c" ] && { LAZ="$c"; break; }
done
if [ -n "${LAZ:-}" ]; then
  lzver="$("$LAZ" --version 2>/dev/null | tr -d '\r' | head -1)"
  echo "TOOL|lazbuild|ok|$(norm "$LAZ")|${lzver:-?}"; LAZBUILD_OK=1
else
  echo "TOOL|lazbuild|absent|"
fi

# --- 5. Delphi (на этой машине отсутствует; ветка не проверена) ----------------
DCC=""
for c in "$(command -v dcc32 2>/dev/null || true)" "$(command -v dcc64 2>/dev/null || true)"; do
  [ -n "$c" ] && [ -x "$c" ] && { DCC="$c"; break; }
done
if [ -z "$DCC" ]; then
  pf86="$(printenv 'ProgramFiles(x86)' 2>/dev/null || true)"
  pf="$(printenv 'ProgramFiles' 2>/dev/null || true)"
  for c in "$pf86"/Embarcadero/Studio/*/bin/dcc32.exe "$pf86"/Embarcadero/Studio/*/bin/dcc64.exe \
           "$pf"/Embarcadero/Studio/*/bin/dcc32.exe "$pf"/Embarcadero/Studio/*/bin/dcc64.exe
  do [ -f "$c" ] && { DCC="$c"; break; }; done
fi
DELPHI_OK=0
if [ -n "$DCC" ]; then
  dver="$("$DCC" --version 2>/dev/null | tr -d '\r' | head -1)"
  echo "TOOL|delphi|ok|$(norm "$DCC")|${dver:-?}"; DELPHI_OK=1
else
  echo "TOOL|delphi|absent|"
fi

# --- 6. смешанные установки ---------------------------------------------------
if [ -n "${LAZARUSDIR:-}" ] && [ -n "$CHOSEN" ]; then
  lz="$(norm "$LAZARUSDIR")"; same=0
  for fp in $CHOSEN; do case "$fp" in "$lz"/*) same=1 ;; esac; done
  [ "$same" = 0 ] && echo "WARN|mixed-toolchain|LAZARUSDIR=$lz|fpc=$(echo $CHOSEN | awk '{print $1}')"
fi
if [ "$FPC_COUNT" -gt 1 ]; then
  echo "WARN|two-fpc|$(echo $CHOSEN | awk '{print $1}')|$(echo $CHOSEN | awk '{print $2}')"
fi

# --- 7. зависимости -----------------------------------------------------------
TESTS_DEP=0
WRAP_REL="../pas_TestingWrapper/Pkg/LZ/glvtestcross.lpk"
if [ -f "$WRAP_REL" ]; then
  units=""
  for d in ../pas_TestingWrapper/Out/*/*; do
    [ -f "$d/Glv.Testing.App.ppu" ] || continue
    rel="${d#../pas_TestingWrapper/Out/}"
    case ":$units:" in *":$rel:"*) ;; *) units="${units:+$units,}$rel" ;; esac
  done
  echo "DEP|GlvTestCross|ok|$WRAP_REL|units=${units:-none}"; TESTS_DEP=1
else
  echo "DEP|GlvTestCross|missing|$WRAP_REL|units=none"
fi
for p in lib/pkg/lz/glv_log_contract.lpk lib/pkg/lz/glv_log_def_engine.lpk \
         lib/pkg/ct/glv_log_def_engine.ctpkg
do
  if [ -f "$p" ]; then echo "DEP|$(basename "$p")|ok|$p"; else echo "DEP|$(basename "$p")|missing|$p"; fi
done

# --- 8. итог ------------------------------------------------------------------
echo "SUMMARY|fpc=$FPC_COUNT|lazbuild=$LAZBUILD_OK|delphi=$DELPHI_OK|tests-dep=$TESTS_DEP"
if [ "$FPC_COUNT" = 0 ] && [ "$LAZBUILD_OK" = 0 ]; then exit 3; fi
if [ "$FPC_COUNT" -gt 0 ] && [ "$LAZBUILD_OK" = 1 ] && [ "$TESTS_DEP" = 1 ]; then exit 0; fi
exit 2
