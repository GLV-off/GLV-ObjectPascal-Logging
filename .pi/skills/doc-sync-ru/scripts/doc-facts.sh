#!/usr/bin/env bash
#
# doc-facts.sh — проверка проверяемых утверждений документации GLV Log.
#
# Утверждение → факт. Каждая проверка — отдельная короткая функция с
# комментарием. Скрипт только читает репозиторий и не пишет файлов.
#
# Использование:
#   bash scripts/doc-facts.sh [корень-репозитория]
#
# Вывод: DOC|<файл>:<строка>|<тип>|<утверждение>|<факт>
#        SUMMARY|checks=<n>|drifts=<n>
# Код: 0 — дрифтов нет; 2 — есть; 64 — аргументы/корень.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$SCRIPT_DIR/../../../..}"

case "${1:-}" in
  -h|--help)
    sed -n '2,15p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac
if [ "$#" -gt 1 ]; then
  echo "ERROR|args|expected: [root]"
  exit 64
fi
if [ ! -d "$ROOT" ]; then
  echo "ERROR|root|not a directory: $ROOT"
  exit 64
fi
ROOT="$(cd "$ROOT" && pwd)" || exit 64
cd "$ROOT" || exit 64
if [ ! -f AGENTS.md ]; then
  echo "ERROR|root|AGENTS.md not found: $ROOT"
  exit 64
fi

DRIFTS=0
CHECKS=0

emit() {
  DRIFTS=$((DRIFTS + 1))
  printf 'DOC|%s\n' "$1"
}

run_check() {
  CHECKS=$((CHECKS + 1))
  "$1"
}

# утверждение AGENTS.md:54 «39 отслеживаемых файлов» → git ls-files
check_tracked_files() {
  local ln claim actual
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'SKIP|tracked|git-absent\n'
    return
  fi
  ln="$(grep -n 'отслеживаемых файлов' AGENTS.md | head -1 | cut -d: -f1)"
  claim="$(grep -oE '[0-9]+ отслеживаемых файлов' AGENTS.md | head -1 | cut -d' ' -f1)"
  actual="$(git ls-files | wc -l | tr -d ' ')"
  [ -z "$claim" ] && return
  if [ "$claim" != "$actual" ]; then
    emit "AGENTS.md:${ln:-54}|count|${claim} tracked files|${actual} (git ls-files)"
  fi
}

# утверждение AGENTS.md:53 «out/ backup/ *.ppu *.o *.exe *.log *.lps под .gitignore» → .gitignore
check_gitignore_patterns() {
  local ln missing="" pat
  [ -f .gitignore ] || return
  for pat in out backup '*.ppu' '*.o' '*.exe' '*.log' '*.lps'; do
    grep -Fxq "$pat" .gitignore || missing="$missing $pat"
  done
  [ -z "$missing" ] && return
  ln="$(grep -n 'Диффы держать чистыми' AGENTS.md | head -1 | cut -d: -f1)"
  emit "AGENTS.md:${ln:-53}|ignore|out/ backup/ *.ppu *.o *.exe *.log *.lps under .gitignore|missing:${missing}"
}

# утверждение AGENTS.md:35 и README.md:191-192 «пути существуют» → проверка ФС
check_doc_paths() {
  local f ln p matches
  for f in AGENTS.md README.md; do
    [ -f "$f" ] || continue
    matches="$(grep -nEo '(lib|test|doc|demos)/[A-Za-z0-9_./-]+\.(pas|inc|lpk|lpi|lpr|dpr|dproj|ctpr|ctpkg|ppr|md|txt)' "$f" | sort -u || true)"
    [ -z "$matches" ] && continue
    while IFS=: read -r ln p; do
      [ -z "$p" ] && continue
      [ -e "$p" ] && continue
      case "$p" in
        out/*|backup/*|*.lps|*"<"*|*"*"*|*"..."*) continue ;;
      esac
      emit "$f:$ln|path|$p|missing"
    done <<< "$matches"
  done
}

# утверждение doc/units.md:11 «GLV.Log.AsyncFileEngine» → файл в lib/src
check_async_unit() {
  local ln
  ln="$(grep -n 'GLV.Log.AsyncFileEngine' doc/units.md 2>/dev/null | head -1 | cut -d: -f1)"
  [ -z "$ln" ] && return
  [ -f lib/src/GLV.Log.AsyncFileEngine.pas ] && return
  emit "doc/units.md:$ln|unit|GLV.Log.AsyncFileEngine|not in lib/src"
}

# утверждение AGENTS.md:80 «формат TPrimitiveFileLog» → реализация в lib/src
check_format_primitive() {
  local ln
  ln="$(grep -n 'TPrimitiveFileLog' AGENTS.md | head -1 | cut -d: -f1)"
  grep -Fq "FormatDateTime('yyyy-mm-dd hh:nn:ss'" lib/src/*.pas && return
  emit "AGENTS.md:${ln:-80}|format|yyyy-mm-dd hh:nn:ss [LEVEL] text|not found in lib/src/*.pas"
}

# утверждение AGENTS.md:81 «формат TAsyncFileLog» → реализация в lib/src
check_format_async() {
  local ln
  ln="$(grep -n 'TAsyncFileLog` | `' AGENTS.md | head -1 | cut -d: -f1)"
  grep -Fq "FBuffer.Add('['" lib/src/*.pas && grep -Fq "']: '" lib/src/*.pas && return
  emit "AGENTS.md:${ln:-81}|format|[LEVEL]: text|not found in lib/src/*.pas"
}

# утверждение AGENTS.md:82 «формат TConsole.ConsoleLog» → реализация в lib/src
check_format_console() {
  local ln
  ln="$(grep -n 'TConsole.ConsoleLog' AGENTS.md | head -1 | cut -d: -f1)"
  grep -Fq "': t.id='" lib/src/*.pas && grep -Fq "', m='" lib/src/*.pas && return
  emit "AGENTS.md:${ln:-82}|format|LEVEL: t.id=<ThreadID>, m=text|not found in lib/src/*.pas"
}

# утверждение AGENTS.md:83 «AsStr иначе UNKNOWN» → активная ветка в GlvLogTypes.pas
check_asstr_unknown() {
  local ln
  grep -q 'UNKNOWN' AGENTS.md || return
  ln="$(grep -n 'TLogLvl.AsStr' AGENTS.md | head -1 | cut -d: -f1)"
  grep -Eq "^[[:space:]]*(else[[:space:]]+)?Result[[:space:]]*:=[[:space:]]*'UNKNOWN'" lib/src/GlvLogTypes.pas && return
  emit "AGENTS.md:${ln:-83}|contract|AsStr: INFO/DEBUG/ERROR/WARN, иначе UNKNOWN|no active UNKNOWN branch (commented out)"
}

# утверждение AGENTS.md:46-48 «Test.lpi требует glv_log_contract» → RequiredPackages
check_test_requires() {
  local ln t i actual_t actual_i
  ln="$(grep -n 'glv_log_contract.*Test.lpi' AGENTS.md | head -1 | cut -d: -f1)"
  [ -z "$ln" ] && return
  t="$(grep -o 'PackageName Value="[^"]*"' test/pkg/lz/Test.lpi | sed 's/.*="//;s/"$//' | sort -u)"
  i="$(grep -o 'PackageName Value="[^"]*"' test/pkg/lz/TestInt.lpi | sed 's/.*="//;s/"$//' | sort -u)"
  printf '%s\n' "$t" | grep -qx 'glv_log_def_engine' || return
  actual_t="$(printf '%s\n' "$t" | tr '\n' ',' | sed 's/,$//')"
  actual_i="$(printf '%s\n' "$i" | tr '\n' ',' | sed 's/,$//')"
  emit "AGENTS.md:$ln|test-requires|Test.lpi -> glv_log_contract|Test.lpi -> $actual_t; TestInt.lpi -> $actual_i"
}

# утверждение AGENTS.md:40-42 «FPC в PATH нет, сборка только через Lazarus» → S1 probe
check_env_compiler() {
  local ln out count paths probe
  ln="$(grep -n 'FPC в PATH' AGENTS.md | head -1 | cut -d: -f1)"
  if command -v fpc >/dev/null 2>&1; then
    emit "AGENTS.md:${ln:-40}|env|FPC in PATH absent|fpc in PATH: $(command -v fpc)"
    return
  fi
  probe="$ROOT/.pi/skills/pascal-build-probe/scripts/probe.sh"
  [ -f "$probe" ] || { printf 'SKIP|compiler|probe-absent\n'; return; }
  out="$(bash "$probe" 2>/dev/null || true)"
  count="$(printf '%s\n' "$out" | sed -n 's/^SUMMARY|fpc=\([0-9][0-9]*\).*/\1/p' | head -1)"
  [ -z "$count" ] && count=0
  paths="$(printf '%s\n' "$out" | grep '^TOOL|fpc' | cut -d'|' -f4 | tr '\n' ',' | sed 's/,$//')"
  if [ "$count" -gt 0 ]; then
    emit "AGENTS.md:${ln:-40}|env|FPC in PATH absent; build only via Lazarus/Typhon|probe: fpc=$count outside PATH: $paths"
  fi
}

run_check check_tracked_files
run_check check_gitignore_patterns
run_check check_doc_paths
run_check check_async_unit
run_check check_format_primitive
run_check check_format_async
run_check check_format_console
run_check check_asstr_unknown
run_check check_test_requires
run_check check_env_compiler

printf 'SUMMARY|checks=%d|drifts=%d\n' "$CHECKS" "$DRIFTS"
if [ "$DRIFTS" -gt 0 ]; then
  exit 2
fi
exit 0
