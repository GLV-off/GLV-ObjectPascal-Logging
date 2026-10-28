#!/usr/bin/env bash
# Module: test-skeleton.sh
# Author: <проект>
# Description: Печатает скелет TCrossTestCase и строку CrossRegTest для
#              конвенции GLV Log. Ничего не пишет на диск.
# History: 2026-02-14: Created
#
# Usage: bash scripts/test-skeleton.sh <Unit|Int> <TName>
# Exit:  0 — скелет напечатан; 2 — неверный режим/имя; 64 — аргументы.
set -uo pipefail

usage() {
  echo "Usage: bash scripts/test-skeleton.sh <Unit|Int> <TName>"
  echo "  Unit — test/src/LogTestUnit.pas, CrossRegTest(..., 'Unit')"
  echo "  Int  — test/src/LogTestInt.pas,  CrossRegTest(..., 'Int'), файлы через TEnv"
  echo "Печатает только stdout; файлы не меняет."
}

if [ "$#" -ne 2 ]; then usage; exit 64; fi
MODE="$1"
NAME="$2"

case "$MODE" in
  Unit) TARGET="test/src/LogTestUnit.pas"; SUBPATH="Unit"; IS_INT=0 ;;
  Int)  TARGET="test/src/LogTestInt.pas";  SUBPATH="Int";  IS_INT=1 ;;
  *) echo "ERROR|bad-mode|$MODE|ожидается Unit|Int" >&2; usage >&2; exit 2 ;;
esac

if ! printf '%s' "$NAME" | grep -Eq '^T[A-Za-z_][A-Za-z0-9_]*$'; then
  echo "ERROR|bad-name|$NAME|имя класса: T + идентификатор (TMyTest)" >&2
  exit 2
fi

cat <<EOF
{ Скелет для $TARGET — вставить частями по комментариям ниже. }
{ Сгенерировано test-skeleton.sh; на диск ничего не записано. }
{ Published-методы должны быть без параметров. SetUp/TearDown вызываются на каждый тест. }
{ Новый файл-юнит нужно добавить в <Units> соответствующего .lpi (см. S2). }

{ --- 1. В interface, в блок type --- }
type
  $NAME = class(TCrossTestCase)
EOF

if [ "$IS_INT" = 1 ]; then
  cat <<'EOF'
  strict private
    FFilepath: TFilepath;
EOF
fi

cat <<'EOF'
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestExample;
  end;

{ --- 2. В implementation; нужные uses уже есть в целевом файле. --- }
EOF

if [ "$IS_INT" = 1 ]; then
  cat <<EOF
procedure $NAME.SetUp;
begin
  FFilepath := TEnv.TestFile;
  TstDeleteFile(FFilepath);
end;

procedure $NAME.TearDown;
begin
  TstDeleteFile(FFilepath);
  FFilepath := '';
end;

procedure $NAME.TestExample;
begin
  { Интеграционный тест: создать данные через логгер, затем прочитать
    TstReadLines(FFilepath) и проверить строки. Файл уже удалится в TearDown. }
  Assert.IsTrue(True, 'заменить на реальную проверку');
end;

{ --- 3. В initialization целевого файла --- }
CrossRegTest($NAME, '$SUBPATH');
EOF
else
  cat <<EOF
procedure $NAME.SetUp;
begin
end;

procedure $NAME.TearDown;
begin
end;

procedure $NAME.TestExample;
begin
  Assert.IsTrue(True, 'заменить на реальную проверку');
end;

{ --- 3. В initialization целевого файла --- }
CrossRegTest($NAME, '$SUBPATH');
EOF
fi
