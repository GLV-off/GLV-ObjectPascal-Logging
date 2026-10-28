#!/usr/bin/env bash
# design-facts.sh — структурные факты для брейншторма по SOLID/YAGNI/KISS/GRASP.
#
# Печатает: объём юнитов, рёбра uses (только interface), объявления классов и
# записей с предками, fan-in публичных типов (упоминаний ВНЕ юнита объявления),
# объём поведения/состояния на юнит, глобальное и статическое состояние,
# сайты освобождения, TODO/FIXME/deprecated, публичную поверхность фасада.
#
# Использование:
#   bash scripts/design-facts.sh [корень-репо] [каталог-исходников]
# По умолчанию: корень = ".", исходники = первый существующий из
# lib/src, src, source; иначе весь корень с фильтром *.pas.
#
# Скрипт только читает, ничего не меняет. rg не обязателен.

set -u

ROOT="${1:-.}"; ROOT="${ROOT%/}"; [ -n "$ROOT" ] || ROOT="/"
SRC="${2:-}"

if [ ! -d "$ROOT" ]; then
  echo "design-facts.sh: нет каталога '$ROOT'" >&2
  exit 2
fi

HERE=$(cd "$(dirname "$0")" && pwd)
AWK_IFACE="$HERE/iface.awk"
if [ ! -f "$AWK_IFACE" ]; then
  echo "design-facts.sh: рядом нет iface.awk ($AWK_IFACE)" >&2
  exit 2
fi

if [ -z "$SRC" ]; then
  for cand in lib/src src source; do
    if [ -d "$ROOT/$cand" ]; then SRC="$ROOT/$cand"; break; fi
  done
fi
[ -n "$SRC" ] || SRC="$ROOT"

TMP=$(mktemp -d 2>/dev/null || echo "/tmp/design-facts.$$")
mkdir -p "$TMP"
LIST="$TMP/files.txt"
find "$SRC" -type f -name '*.pas' -not -path '*/backup/*' | sort > "$LIST"

if [ ! -s "$LIST" ]; then
  echo "design-facts.sh: в '$SRC' нет *.pas" >&2
  rm -rf "$TMP"
  exit 1
fi

section() {
  printf '\n%s\n## %s\n%s\n' \
    "------------------------------------------------------------" \
    "$1" \
    "------------------------------------------------------------"
}

# --------------------------------------------------------------------------
section "Окружение"
printf 'root       : %s\n' "$ROOT"
printf 'sources    : %s\n' "$SRC"
printf 'units      : %s\n' "$(wc -l < "$LIST" | tr -d ' ')"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  printf 'git        : %s @ %s\n' \
    "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
    "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
  printf 'незакоммич.: %s файл(ов) (git status --porcelain)\n' \
    "$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
else
  printf 'git        : нет\n'
fi

# --------------------------------------------------------------------------
section "Объём юнитов (строк, по убыванию)"
xargs wc -l < "$LIST" 2>/dev/null | sed '$d' | sort -rn

# --------------------------------------------------------------------------
section "Рёбра uses (только interface)"
while IFS= read -r f; do
  awk -f "$AWK_IFACE" "$f" | awk -v name="$(basename "$f")" '
    { buf = buf " " $0 }
    END {
      if (match(tolower(buf), /(^|[ \t])uses([ \t]|$)/)) {
        rest = substr(buf, RSTART)
        sub(/^[ \t]*uses/, "", rest)
        sub(/;.*$/, "", rest)
        n = split(rest, parts, ",")
        printf "%s ->", name
        for (i = 1; i <= n; i++) {
          gsub(/^[ \t]+|[ \t]+$/, "", parts[i])
          if (parts[i] != "") printf " %s", parts[i]
        }
        printf "\n"
      }
    }
  '
done < "$LIST" | sort
echo "(нет строки = uses в interface отсутствует)"

# --------------------------------------------------------------------------
section "Классы и записи с методами (имя, предок, место, модификаторы)"
: > "$TMP/decls.txt"
while IFS= read -r f; do
  grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(class|record)\b' "$f" 2>/dev/null \
    | grep -vE '=[[:space:]]*(class|record)[[:space:]]*(of)?[[:space:]]*;' \
    | while IFS=: read -r ln decl; do
        printf '%s\t%s\t%s\n' "$f" "$ln" "$decl"
      done >> "$TMP/decls.txt"
done < "$LIST"

if [ -s "$TMP/decls.txt" ]; then
  while IFS="$(printf '\t')" read -r f ln decl; do
    name=$(printf '%s' "$decl" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*).*/\1/')
    parent=$(printf '%s' "$decl" | sed -nE 's/.*(class|record)[^(]*\(([^)]*)\).*/\2/p')
    mods=$(printf '%s' "$decl" | sed -E 's/.*(class|record)[[:space:]]*//; s/[[:space:]]*\(.*//; s/[[:space:]]*;.*//')
    [ -n "$mods" ] || mods="-"
    printf '%-30s %-24s %s:%s  [%s]\n' "$name" "${parent:-<нет>}" "$(basename "$f")" "$ln" "$mods"
  done < "$TMP/decls.txt"
else
  echo "(классов/записей не найдено)"
fi

# --------------------------------------------------------------------------
section "Fan-in типов (упоминаний вне юнита объявления)"
if [ -s "$TMP/decls.txt" ]; then
  printf '%-30s %s\n' "тип" "внешних"
  while IFS="$(printf '\t')" read -r f ln decl; do
    name=$(printf '%s' "$decl" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*).*/\1/')
    total=0
    while IFS= read -r g; do
      [ "$g" = "$f" ] && continue
      c=$(grep -wo -c "$name" "$g" 2>/dev/null | head -1)
      total=$((total + ${c:-0}))
    done < "$LIST"
    printf '%-30s %s\n' "$name" "$total"
  done < "$TMP/decls.txt"
fi
cat <<'EOF'

  Читать так: 0-1 = тип живёт сам для себя (аргумент за KISS и против
  обобщения «на будущее»); высокий fan-in = изменение типа дорого, здесь
  цены SOLID/OCP реальны. Дубли имён = тип объявлен в двух поколениях API.
EOF

# --------------------------------------------------------------------------
section "Объём поведения и состояния на юнит"
printf '%-30s %8s %8s\n' "unit" "методов" "полей F*"
while IFS= read -r f; do
  meth=$(awk -f "$AWK_IFACE" "$f" \
    | grep -cE '^[[:space:]]*(class[[:space:]]+)?(procedure|function|constructor|destructor)\b' 2>/dev/null \
    | head -1)
  fld=$(grep -oE '\bF[A-Z][A-Za-z0-9_]*\b' "$f" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  printf '%-30s %8s %8s\n' "$(basename "$f")" "${meth:-0}" "$fld"
done < "$LIST"

# --------------------------------------------------------------------------
section "Глобальное и статическое состояние (кандидаты в TENSION DIP vs KISS)"
while IFS= read -r f; do
  grep -nE '^(var|threadvar|class var)\b|^[[:space:]]*(class var|initialization|finalization)\b|^[[:space:]]*class[[:space:]]+(constructor|procedure|function)\b' "$f" 2>/dev/null \
    | sed "s#^#$(basename "$f"):#"
done < "$LIST"

# --------------------------------------------------------------------------
section "Сайты освобождения (кто владеет)"
while IFS= read -r f; do
  grep -nE '\bFreeAndNil[[:space:]]*\(|[^A-Za-z0-9_]Free\b' "$f" 2>/dev/null \
    | sed "s#^#$(basename "$f"):#"
done < "$LIST" | head -40

# --------------------------------------------------------------------------
section "Долги: TODO/FIXME/HACK/deprecated/заглушки"
while IFS= read -r f; do
  grep -nEi 'TODO|FIXME|HACK|XXX|deprecated|not implemented|заглушк' "$f" 2>/dev/null \
    | sed "s#^#$(basename "$f"):#"
done < "$LIST"

# --------------------------------------------------------------------------
section "Публичная поверхность фасада (interface-часть)"
FACADES="$TMP/facades.txt"
grep -E '/(GlvLog|GLV\.Log|Log|Logger)\.pas$' "$LIST" > "$FACADES" 2>/dev/null || true
[ -s "$FACADES" ] || head -1 "$LIST" > "$FACADES"
while IFS= read -r f; do
  echo "--- $(basename "$f")"
  awk -f "$AWK_IFACE" "$f" | sed '/^[[:space:]]*$/d'
done < "$FACADES"

rm -rf "$TMP"
printf '\nДальше: линзы принципов -> references/principle-lenses.md\n'
