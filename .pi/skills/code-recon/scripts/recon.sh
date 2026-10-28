#!/usr/bin/env bash
# Module: recon.sh
# Author: <проект>
# Description: Быстрый снимок репозитория для разведки перед ревью/правками.
#              Только чтение: ничего не пишет в дерево, не меняет git-состояние.
# History: 2026-02-14: Created
#
# Usage: bash scripts/recon.sh [repo-root]     (по умолчанию — текущий каталог)
#
# Degradation:
#   - нет git  -> перечисление файлов через find, git-раздел пропускается;
#   - нет rg   -> поиск через grep -rnE;
#   - нет wc   -> разделы с подсчётом строк пропускаются.
set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "!! нет каталога: $ROOT" >&2; exit 1; }

hr() { printf '\n== %s ==\n' "$*"; }
note() { printf '%s\n' "$*"; }

# --- обнаружение инструментов -------------------------------------------------
HAS_GIT=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then HAS_GIT=1; fi

HAS_RG=0
if command -v rg >/dev/null 2>&1; then HAS_RG=1; fi

HAS_WC=0
if command -v wc >/dev/null 2>&1; then HAS_WC=1; fi

# search <pattern> — печатает path:line:text, пропуская служебные и сборочные
# каталоги (.git, .pi, out, backup, ...). rg уважает .gitignore сам, grep — нет.
search() {
  local pat="$1"
  if [ "$HAS_RG" = 1 ]; then
    rg -n --no-heading -g '!.git/**' -g '!.pi/**' -e "$pat" . 2>/dev/null
  else
    grep -rnE -I \
      --exclude-dir=.git --exclude-dir=.pi --exclude-dir=out \
      --exclude-dir=backup --exclude-dir=__history --exclude-dir=node_modules \
      -e "$pat" . 2>/dev/null
  fi
}

list_files() {
  if [ "$HAS_GIT" = 1 ]; then
    git ls-files
  else
    find . -type f -not -path './.git/*'
  fi
}

FILES="$(list_files | sort)"
if [ -z "$FILES" ]; then echo "!! файлов не найдено в $(pwd)" >&2; exit 0; fi

# --- 1. состояние репозитория -------------------------------------------------
hr "1. Состояние репозитория"
note "корень: $(pwd)"
if [ "$HAS_GIT" = 1 ]; then
  note "ветка:  $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  note "HEAD:   $(git log -1 --oneline 2>/dev/null)"
  note "отслеживается файлов: $(printf '%s\n' "$FILES" | wc -l 2>/dev/null || echo '?')"
  dirty="$(git status --porcelain 2>/dev/null | wc -l 2>/dev/null || echo '?')"
  note "изменено/не в индексе: $dirty"
  if [ "${dirty:-0}" != "0" ]; then
    note "--- git status --porcelain ---"
    git status --porcelain 2>/dev/null | head -40
  fi
  note "--- последние коммиты ---"
  git log --oneline -10 2>/dev/null
else
  note "git: недоступен (не репозиторий или git не установлен)"
  note "файлов: $(printf '%s\n' "$FILES" | wc -l 2>/dev/null || echo '?')"
fi

# --- 2. объём по верхним каталогам --------------------------------------------
hr "2. Файлы по верхним каталогам (файлов / строк)"
if [ "$HAS_WC" = 1 ]; then
  printf '%s\n' "$FILES" | xargs -r wc -l 2>/dev/null | awk '
    $2 == "total" { next }
    NF >= 2 {
      n = split($2, a, "/")
      d = (n > 1 ? a[1] : ".")
      lines[d] += $1; cnt[d]++; total += $1; tcnt++
    }
    END {
      for (d in cnt) printf "%8d %6d  %s\n", lines[d], cnt[d], d
      printf "%8d %6d  ВСЕГО\n", total, tcnt
    }' | sort -rn
else
  printf '%s\n' "$FILES" | awk -F/ '{print (NF>1?$1:".")}' | sort | uniq -c | sort -rn
fi

hr "3. Крупнейшие файлы (топ-12)"
if [ "$HAS_WC" = 1 ]; then
  printf '%s\n' "$FILES" | xargs -r wc -l 2>/dev/null \
    | awk '$2 != "total"' | sort -rn | head -12
else
  note "wc недоступен"
fi

# --- 4. файлы правил и документации ------------------------------------------
hr "4. Правила, доки, конфиги"
found=0
for f in AGENTS.md CLAUDE.md CONTRIBUTING.md README.md .editorconfig \
         .gitattributes .gitignore Makefile package.json; do
  if [ -f "$f" ]; then
    printf '  %-18s %6s строк\n' "$f" "$(wc -l < "$f" 2>/dev/null || echo '?')"
    found=1
  fi
done
printf '%s\n' "$FILES" | grep -iE '^(doc|docs)/.*\.(md|txt|rst)$' 2>/dev/null | head -20 \
  | while read -r f; do printf '  %s\n' "$f"; done
[ "$found" = 0 ] && note "  (файлы правил не найдены — сверяться не с чем, это уже находка)"

# --- 5. точки сборки ---------------------------------------------------------
hr "5. Точки сборки / пакеты / автоген"
printf '%s\n' "$FILES" | grep -iE '\.(lpi|lpk|lpr|dpr|dproj|ctpkg|ctpr|ppr|sln|csproj|groupproj|cabal|toml)$|(^|/)(Makefile|CMakeLists\.txt|package\.json)$' 2>/dev/null
note "-- кандидаты в автогенерируемые (рядом с пакетами/проектами, править не вручную):"
printf '%s\n' "$FILES" | awk -F/ '
  { if ($0 ~ /\.pas$/) {
      d = $0; sub(/\/[^\/]*$/, "", d)
      pas[d]++
    } else if ($0 ~ /\.(lpk|dproj|ctpkg|lpi)$/) {
      d = $0; sub(/\/[^\/]*$/, "", d)
      pkg[d]++
    }
  }
  END { for (d in pkg) if (pas[d] != "") printf "  %-40s pas=%d pkg=%d\n", d, pas[d], pkg[d] }'

# --- 6. граф зависимостей (Pascal: uses в interface-части) --------------------
if printf '%s\n' "$FILES" | grep -qi '\.pas$'; then
  hr "6. Зависимости Pascal-юнитов (interface uses)"
  printf '%s\n' "$FILES" | grep -i '\.pas$' | while read -r f; do
    deps="$(awk '
      BEGIN { IGNORECASE = 1; inuses = 0 }
      { low = tolower($0) }
      low ~ /^[ \t]*implementation([ \t]|$)/ { exit }
      low ~ /^[ \t]*uses([ \t]|$)/ { inuses = 1 }
      inuses {
        line = $0
        sub(/^[ \t]*uses[ \t]*/, "", line)
        sub(/\{.*$/, "", line); sub(/\/\/.*$/, "", line)
        printf "%s ", line
        if (line ~ /;/) inuses = 0
      }' "$f" | tr ',' '\n' \
        | sed -e 's/[;[:space:]]//g' -e 's/{.*//' -e 's/^[[:space:]]*//' \
        | grep -viE '^$|^uses$|^implementation$' | sort -u | paste -sd ' ' -)"
    [ -n "${deps:-}" ] && printf '  %-34s -> %s\n' "$(basename "$f")" "$deps"
  done
fi

# --- 7. маркеры долгов -------------------------------------------------------
hr "7. Маркеры (TODO/FIXME/HACK/XXX/deprecated)"
markers="$(search 'TODO|FIXME|HACK|XXX|[Dd]eprecated')"
if [ -n "$markers" ]; then
  printf '%s\n' "$markers" | head -40
  printf '  ... всего строк: %s\n' "$(printf '%s\n' "$markers" | wc -l)"
else
  note "  не найдено"
fi

# --- 8. подозрительные артефакты ---------------------------------------------
hr "8. Артефакты в трекинге (должны быть в .gitignore)"
printf '%s\n' "$FILES" \
  | grep -iE '\.(ppu|o|obj|a|so|dll|exe|log|lps|tmp|bak|~)$|/out/|/build/|/dist/|/__pycache__/' 2>/dev/null \
  | head -30
note "  (пусто = артефактов в трекинге нет)"
note "-- .gitignore --"
if [ -f .gitignore ]; then cat .gitignore; else note "  .gitignore отсутствует"; fi

# --- 9. заготовки и мусор ----------------------------------------------------
hr "9. Заготовки и недоделанное"
printf '%s\n' "$FILES" | grep -iE '(^|/)(backup|bak|old|tmp)/|\.tmp_|\.ppr$' 2>/dev/null | head -20
empty="$(printf '%s\n' "$FILES" | while read -r f; do
  [ -f "$f" ] || continue
  [ "$(wc -c < "$f" 2>/dev/null || echo 1)" -lt 40 ] 2>/dev/null && printf '  %s\n' "$f"
done | head -20)"
if [ -n "$empty" ]; then note "-- почти пустые файлы (кандидаты в заготовки) --"; printf '%s\n' "$empty"; fi

hr "Готово"
note "Дальше: прочитать файлы правил целиком, составить карту модулей,"
note "и только потом формировать находки с привязкой путь:строка."
