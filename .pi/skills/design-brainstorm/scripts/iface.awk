# iface.awk — печатает interface-часть pascal-юнита без комментариев.
# Комментарии { ... }, (* ... *) и // удаляются, включая многострочные;
# строковые литералы не разбираются (в interface они редки).
# Использование: awk -f scripts/iface.awk Unit.pas
{
  low = tolower($0)

  if (inif && low ~ /^[ \t]*implementation/) inif = 0
  if (!incurly && !inparen && low ~ /^[ \t]*interface[ \t;]*$/) { inif = 1; next }
  if (!inif) next

  out = ""
  i = 1
  n = length($0)
  while (i <= n) {
    if (incurly) {
      if (substr($0, i, 1) == "}") incurly = 0
      i++
      continue
    }
    if (inparen) {
      if (substr($0, i, 2) == "*)") { inparen = 0; i += 2; continue }
      i++
      continue
    }
    if (substr($0, i, 2) == "(*") { inparen = 1; i += 2; continue }
    if (substr($0, i, 1) == "{") { incurly = 1; i++; continue }
    if (substr($0, i, 2) == "//") break
    out = out substr($0, i, 1)
    i++
  }

  sub(/[ \t]+$/, "", out)
  print out
}
