unit TestFileUtils;

{$I 'glv_log_test.inc'}

interface

type
  TLine = UnicodeString;
  TFilepath = TLine;
  TLines = TArray<TLine>;

function TstReadLines(const AFilepath: TFilepath): TLines;
function TstDeleteFile(const AFilepath: TFilepath): Boolean;

implementation

uses
  SysUtils,
  Classes;

function TstReadLines(const AFilepath: TFilepath): TLines;
var
  Lines: TStringList;
  I: LongInt;
begin
  Result := [];
  Lines := TStringList.Create();
  try
    try
      Lines.LoadFromFile(UTF8Encode(AFilepath), TEncoding.Utf8);
    except
      on E: Exception do
        Lines.Clear();
    end;

    if Lines.Count > 0 then
    begin
      SetLength(Result, Lines.Count);
      for I := 0 to Lines.Count - 1 do
        Result[I] := UTF8Decode(Lines[I]);
    end
    else
      Result := [];
  finally
    FreeAndNil(Lines);
  end;
end;

function TstDeleteFile(const AFilepath: TFilepath): Boolean;
begin
  Result := SysUtils.DeleteFile(AFilepath);
end;

end.

