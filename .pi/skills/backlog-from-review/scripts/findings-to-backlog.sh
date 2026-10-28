#!/usr/bin/env bash
#
# findings-to-backlog.sh — markdown-отчёт ревью → строки бэклога.
#
# Парсит находки по меткам severity (BLOCKER/BUG/RISK/SMELL/DOC) и
# `путь:строка`, дедуплицирует по доказательству и сверяет с существующим
# `doc/backlog_ru.md`. По умолчанию ничего не пишет; `--write` вставляет
# только новые строки перед маркером inbox.
#
# Использование:
#   findings-to-backlog.sh <report.md>
#   findings-to-backlog.sh --write <report.md>
#   findings-to-backlog.sh --backlog /tmp/backlog.md <report.md>
#
# Коды: 0 — ok; 2 — находок нет/не распознаны; 3 — --write без маркера;
#       64 — аргументы; 66 — отчёт/бэклог не найден.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BACKLOG="$ROOT/doc/backlog_ru.md"
WRITE=0
REPORT=""
MARKER="<!-- findings-to-backlog:append -->"
usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --write)
      WRITE=1
      ;;
    --backlog)
      if [ "$#" -lt 2 ]; then
        echo "ERROR|args|--backlog requires a file" >&2
        exit 64
      fi
      BACKLOG="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR|args|unknown option: $1" >&2
      exit 64
      ;;
    *)
      if [ -n "$REPORT" ]; then
        echo "ERROR|args|only one report allowed" >&2
        exit 64
      fi
      REPORT="$1"
      ;;
  esac
  shift
done
if [ -z "$REPORT" ]; then
  usage >&2
  exit 64
fi
if [ "$REPORT" = "-" ]; then
  REPORT="/dev/stdin"
fi
if [ ! -f "$REPORT" ]; then
  echo "ERROR|report|not found: $REPORT" >&2
  exit 66
fi
if [ ! -f "$BACKLOG" ]; then
  echo "ERROR|backlog|not found: $BACKLOG" >&2
  exit 66
fi
ROWS="$(mktemp "${TMPDIR:-/tmp}/backlog-rows.XXXXXX")" || exit 70
TMPB="$(mktemp "${TMPDIR:-/tmp}/backlog-out.XXXXXX")" || { rm -f "$ROWS"; exit 70; }
trap 'rm -f "$ROWS" "$TMPB"' EXIT

# Парсер: одна находка = строка списка/таблицы с evidence; severity берётся
# из ближайшего заголовка `### BUG` или из метки `[BUG]`/`BUG:` в строке.
awk -v backlog="$BACKLOG" -v rowsfile="$ROWS" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function evidence(s,   p) {
  if (match(s, /`[^`]+:[0-9]+`/)) {
    p = substr(s, RSTART + 1, RLENGTH - 2)
    return p
  }
  if (match(s, /[A-Za-z0-9_./-]+\.(pas|md|lpk|lpi|lpr|ctpkg|dpr|inc|sh):[0-9]+/))
    return substr(s, RSTART, RLENGTH)
  return ""
}
function clean_desc(s, ev,   d, p) {
  p = index(s, ev)
  if (p > 0) d = substr(s, p + length(ev))
  else d = s
  gsub(/`/, "", d)
  sub(/^[ \t]*[|—:-]+[ \t]*/, "", d)
  gsub(/\|/, "/", d)
  gsub(/[ \t]+/, " ", d)
  d = trim(d)
  if (length(d) > 140) d = substr(d, 1, 137) "..."
  return d
}
function row(id, cls, ev, d, st) {
  return "| " id " | " cls " | `" ev "` | " d " | " st " |"
}
BEGIN {
  sev = ""; nnew = 0; ndup = 0; maxid = 0
  split("BLOCKER BUG RISK SMELL DOC", SEVS, " ")
  while ((getline l < backlog) > 0) {
    gsub(/\r/, "", l)
    if (match(l, /BL-[0-9]+/)) {
      num = substr(l, RSTART + 3, RLENGTH - 3) + 0
      if (num > maxid) maxid = num
    }
    ev = evidence(l)
    if (ev != "") {
      key = tolower(ev)
      if (!(key in idmap)) {
        if (match(l, /BL-[0-9]+/)) idmap[key] = substr(l, RSTART, RLENGTH)
        else idmap[key] = "?"
      }
    }
  }
  close(backlog)
  nextid = maxid + 1
}
{
  line = $0
  gsub(/\r/, "", line)
  if (line ~ /^##+[ \t]+(BLOCKER|BUG|RISK|SMELL|DOC)[ \t]*$/) {
    sev = line; sub(/^##+[ \t]+/, "", sev); gsub(/[ \t]/, "", sev); next
  }
  if (line ~ /^##[ \t]/) { sev = ""; next }
  lsev = sev
  for (i = 1; i <= 5; i++)
    if (index(line, "[" SEVS[i] "]") > 0) lsev = SEVS[i]
  if (line ~ /^[ \t]*(BLOCKER|BUG|RISK|SMELL|DOC):/) {
    x = line
    sub(/^[ \t]*/, "", x)
    sub(/:.*/, "", x)
    lsev = x
  }
  is_item = (line ~ /^[ \t]*([0-9]+[.)]|[-*])[ \t]+/)
  is_doc_row = (sev == "DOC" && line ~ /^[ \t]*\|/)
  if (!is_item && !is_doc_row) next
  ev = evidence(line)
  if (ev == "") next
  if (lsev == "") {
    print "SKIP|no-severity|" trim(line) > "/dev/stderr"
    next
  }
  key = tolower(ev)
  d = clean_desc(line, ev)
  if (key in idmap) {
    ndup++
    print row(idmap[key], lsev, ev, d, "dup")
    next
  }
  id = sprintf("BL-%03d", nextid)
  nextid++
  idmap[key] = id
  nnew++
  out = row(id, lsev, ev, d, "new")
  print out
  print out > rowsfile
}
END {
  printf "RESULT|new=%d|dup=%d\n", nnew, ndup
  printf "SUMMARY|findings=%d|new=%d|dup=%d\n", nnew + ndup, nnew, ndup
  if (nnew + ndup == 0) exit 2
}
' "$REPORT"
RC=$?
if [ "$WRITE" -eq 1 ] && [ "$RC" -eq 0 ] && [ -s "$ROWS" ]; then
  awk -v rowsfile="$ROWS" -v marker="$MARKER" -v ORS="\r\n" '
    BEGIN {
      n = 0
      while ((getline r < rowsfile) > 0) { sub(/\r$/, "", r); rows[++n] = r }
      close(rowsfile)
    }
    {
      sub(/\r$/, "")
      if ($0 == marker) { for (i = 1; i <= n; i++) print rows[i]; inserted = 1 }
      print
    }
    END { if (!inserted) exit 3 }
  ' "$BACKLOG" > "$TMPB"
  IRC=$?
  if [ "$IRC" -eq 0 ]; then
    mv "$TMPB" "$BACKLOG"
    echo "WROTE|$BACKLOG|new=$(( $(wc -l < "$ROWS") ))"
  else
    echo "ERROR|write|marker not found in $BACKLOG" >&2
    RC=3
  fi
fi
exit "$RC"
