#!/usr/bin/env bash
# Module: pkg-inventory.sh
# Author: <проект>
# Description: Инвентаризация Lazarus/CodeTyphon-пакетов GLV Log: состав,
#              покрытие lib/src, асимметрия v1/v2, десинк автоген-юнитов,
#              дубли из OtherUnitFiles. Ничего не изменяет.
# History: 2026-02-14: Created
#
# Usage: bash scripts/pkg-inventory.sh [repo-root]
# Output: PKG|UNIT|UNITPKG|COVER|ASYM|AUTOGEN|REQ|DUP|OVL|IMPLICIT|SUMMARY
# Exit:   0 = инвентаризация построена; 2 = нет lib/src или пакетов.
set -uo pipefail

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')"
  [ -z "$ROOT" ] && ROOT="$(pwd)"
fi
cd "$ROOT" 2>/dev/null || { echo "SUMMARY|error|no-root"; exit 2; }
[ -d lib/src ] || { echo "SUMMARY|error|no-lib-src"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/glv-pkg.XXXXXX" 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MEM="$TMP/membership.tsv"   # pkg \t unit \t file
AUT="$TMP/autogen.tsv"      # pkg \t unit (из uses)
: >"$MEM"; : >"$AUT"

val() { awk -F'"' -v tag="$1" 'index($0,tag){print $2; exit}' "$2"; } # val '<Name Value=' file
base_of() { printf '%s' "${1##*[\\/]}"; }

# --- 1. пакеты и их состав ----------------------------------------------------
PKGS="$(find lib/pkg -type f \( -name '*.lpk' -o -name '*.ctpkg' \) ! -path '*/backup/*' 2>/dev/null | sort)"
[ -n "$PKGS" ] || { echo "SUMMARY|error|no-packages"; exit 2; }
PKG_N=0; UNIT_N=0
for p in $PKGS; do
  kind="${p##*.}"; name="$(val '<Name Value=' "$p")"; [ -n "$name" ] || name="$(basename "$p" ".$kind")"
  ver="$(awk '/<Package Version=/{gsub(/[^0-9]/,"",$0); print; exit}' "$p")"
  un="$(awk -F'"' '/<Files>/{f=1;next} /<\/Files>/{f=0}
        f&&/<Filename Value=/{fn=$2} f&&/<UnitName Value=/{print fn "\t" $2}' "$p")"
  cnt="$(printf '%s\n' "$un" | awk 'NF{n++}END{print n+0}')"
  echo "PKG|$p|$name|$kind|${ver:-?}|units=$cnt"
  printf '%s\n' "$un" | while IFS="$(printf '\t')" read -r fn u; do
    [ -n "$u" ] || continue
    echo "UNIT|$name|$u"
    printf '%s\t%s\t%s\t%s\n' "$p" "$name" "$u" "$fn" >>"$MEM"
  done
  PKG_N=$((PKG_N + 1)); UNIT_N=$((UNIT_N + cnt))
done

# unit -> packages (обратная таблица), только встречающиеся в пакетах
awk -F'\t' '{k=tolower($3); if(!(k in seen)){seen[k]=$3; order[++n]=k}
             pkgs[k]=pkgs[k] (pkgs[k]?",":"") $2}
  END{for(i=1;i<=n;i++) print "UNITPKG|" seen[order[i]] "|" pkgs[order[i]]}' "$MEM" | sort -t'|' -k2,2

# --- 2. покрытие lib/src ------------------------------------------------------
SRC_N=0; COV_N=0; MISSING=""
for f in lib/src/*.pas; do
  [ -e "$f" ] || continue
  SRC_N=$((SRC_N + 1)); b="$(base_of "$f")"; b="${b%.pas}"
  m="$(awk -F'\t' -v u="$b" 'tolower($3)==tolower(u){print; exit}' "$MEM")"
  if [ -n "$m" ]; then COV_N=$((COV_N + 1)); else MISSING="${MISSING:+$MISSING,}$b"; fi
done
echo "COVER|src=$SRC_N|covered=$COV_N|uncovered=$((SRC_N - COV_N))|missing=${MISSING:-none}"

# --- 3. асимметрия v1/v2 ------------------------------------------------------
V1="$(for p in $PKGS; do case "$p" in *.ctpkg) awk -F'\t' -v n="$p" '$1==n{print $3}' "$MEM";; esac; done | sort -u)"
V2="$(for p in $PKGS; do case "$p" in *.lpk) awk -F'\t' -v n="$p" '$1==n{print $3}' "$MEM";; esac; done | sort -u)"
V1_ONLY="$(comm -23 <(printf '%s\n' "$V1") <(printf '%s\n' "$V2") | sed '/^$/d' | paste -sd, -)"
V2_ONLY="$(comm -13 <(printf '%s\n' "$V1") <(printf '%s\n' "$V2") | sed '/^$/d' | paste -sd, -)"
BOTH="$(comm -12 <(printf '%s\n' "$V1") <(printf '%s\n' "$V2") | sed '/^$/d' | paste -sd, -)"
echo "ASYM|v1=$(printf '%s\n' "$V1" | sed '/^$/d' | wc -l | tr -d ' ')|v2=$(printf '%s\n' "$V2" | sed '/^$/d' | wc -l | tr -d ' ')|both=$([ -n "$BOTH" ] && echo yes || echo no)|v1_only=${V1_ONLY:-none}|v2_only=${V2_ONLY:-none}"

# --- 4. десинк автоген-юнита --------------------------------------------------
AUT_BAD=0
for p in $PKGS; do
  d="$(dirname "$p")"; b="$(basename "$p")"; b="${b%.*}"; g="$d/$b.pas"
  [ -f "$g" ] || { echo "AUTOGEN|$p|missing|generated-unit=$g"; continue; }
  awk -v pkg="$p" '
    /^[[:space:]]*uses([[:space:]]|$)/ {u=1; sub(/^[[:space:]]*uses[[:space:]]*/,""); }
    u { line=$0; gsub(/[[:space:]]/,"",line); n=split(line,a,",");
        for(i=1;i<=n;i++){sub(/;.*/,"",a[i]); if(a[i]!="") print pkg "\t" a[i]}
        if(line ~ /;/) u=0 }
    /^[[:space:]]*implementation/ {u=0}' "$g" >>"$AUT"
  files="$(awk -F'\t' -v n="$p" '$1==n{print $3}' "$MEM")"
  uses="$(awk -F'\t' -v n="$p" '$1==n{print $2}' "$AUT" | grep -v '^TyphonPackageIntf$')"
  miss="$(comm -23 <(printf '%s\n' "$files" | tr 'A-Z' 'a-z' | sort -u) \
                    <(printf '%s\n' "$uses"  | tr 'A-Z' 'a-z' | sort -u) | paste -sd, -)"
  extra="$(comm -13 <(printf '%s\n' "$files" | tr 'A-Z' 'a-z' | sort -u) \
                    <(printf '%s\n' "$uses"  | tr 'A-Z' 'a-z' | sort -u) | paste -sd, -)"
  nf="$(printf '%s\n' "$files" | sed '/^$/d' | wc -l | tr -d ' ')"
  nu="$(printf '%s\n' "$uses" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ -z "$miss" ] && [ -z "$extra" ] && [ "$nf" = "$nu" ]; then
    echo "AUTOGEN|$p|ok|uses=$nu|files=$nf"
  else
    echo "AUTOGEN|$p|desync|uses=$nu|files=$nf|missing=${miss:-none}|extra=${extra:-none}"; AUT_BAD=1
  fi
done

# --- 5. потребители: RequiredPkgs, OtherUnitFiles, дубли ----------------------
resolve() { # resolve <base> <rel-with-backslashes> -> абсолютный POSIX или пусто
  local rel="${2//\\//}"
  case "$rel" in ''|*'$('*) return 1;; esac
  case "$rel" in /*|[A-Za-z]:/*) printf '%s' "$rel";; *) realpath -m "$1/$rel" 2>/dev/null;; esac
}
under() {
  [ -n "$2" ] || return 1
  [ "$2" = "$1" ] && return 0
  case "$2" in "$1"/*) return 0;; esac
  return 1
}

DUP_N=0; OVL_N=0; LPI_N=0
for lpi in $(find test demos -type f -name '*.lpi' ! -path '*/backup/*' 2>/dev/null | sort); do
  LPI_N=$((LPI_N + 1)); dir="$(dirname "$lpi")"
  reqs="$(awk -F'"' '/<RequiredPackages>/{f=1;next} /<\/RequiredPackages>/{f=0}
        f&&/<PackageName Value=/{print $2}' "$lpi" | paste -sd, -)"
  echo "REQ|$lpi|${reqs:-none}"
  # пути поиска (BuildModes и default), только реальные каталоги
  : >"$TMP/sp"
  awk -F'"' '/<OtherUnitFiles Value=/{print $2}' "$lpi" | tr ';' '\n' | while read -r sp; do
    [ -n "$sp" ] || continue
    a="$(resolve "$dir" "$sp")" || continue
    [ -d "$a" ] && printf '%s\t%s\n' "$a" "$sp" >>"$TMP/sp"
  done
  # Files: юнит из проекта, который ещё и лежит в OtherUnitFiles
  awk -F'"' '/<Units>/{f=1;next} /<\/Units>/{f=0}
        f&&/<Filename Value=/{print $2}' "$lpi" | while read -r fn; do
    case "$fn" in *.pas) ;; *) continue;; esac
    a="$(resolve "$dir" "$fn")" || continue
    ad="$(dirname "$a")"
    while IFS="$(printf '\t')" read -r sp sr; do
      under "$sp" "$ad" && { echo "DUP|$lpi|$(base_of "$fn")|search=$sr"; break; }
    done <"$TMP/sp"
  done >>"$TMP/dup"
  # RequiredPkgs: юнит пакета, чей исходник попадает в путь поиска проекта
  while IFS='|' read -r _ pn; do
    for p in $PKGS; do
      [ "$(val '<Name Value=' "$p")" = "$pn" ] || continue
      pdir="$(dirname "$p")"
      while IFS="$(printf '\t')" read -r m_pkg m_name m_unit m_file; do
        [ "$m_pkg" = "$p" ] || continue
        a="$(resolve "$pdir" "$m_file")" || continue
        while IFS="$(printf '\t')" read -r sp sr; do
          under "$sp" "$(dirname "$a")" && echo "OVL|$lpi|$pn|$m_unit|search=$sr"
        done <"$TMP/sp"
      done <"$MEM"
    done
  done < <(awk -F'"' '/<RequiredPackages>/{f=1;next} /<\/RequiredPackages>/{f=0}
        f&&/<PackageName Value=/{print "R|" $2}' "$lpi") >>"$TMP/ovl"
done

if [ -s "$TMP/dup" ]; then sort -u "$TMP/dup"; DUP_N="$(sort -u "$TMP/dup" | wc -l | tr -d ' ')"; else echo "DUP|none"; fi
if [ -s "$TMP/ovl" ]; then sort -u "$TMP/ovl"; OVL_N="$(sort -u "$TMP/ovl" | wc -l | tr -d ' ')"; else echo "OVL|none"; fi

# --- 6. RequiredPkgs ----------------------------------------------------------
for p in $PKGS; do
  r="$(awk -F'"' '/<RequiredPkgs>/{f=1;next} /<\/RequiredPkgs>/{f=0} f&&/<PackageName Value=/{print $2}' "$p" | paste -sd, -)"
  echo "REQUIRED|$p|${r:-none}"
done

# --- 7. итог ------------------------------------------------------------------
echo "SUMMARY|packages=$PKG_N|units=$UNIT_N|src=$SRC_N|covered=$COV_N|uncovered=$((SRC_N - COV_N))|dups=$DUP_N|ovl=$OVL_N|autogen_desync=$AUT_BAD|projects=$LPI_N"
