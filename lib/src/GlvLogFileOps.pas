unit GlvLogFileOps;

{$I 'glv_log_lib.inc'}

interface

uses
  Classes,
  SysUtils;

procedure TestFileOps;

type
  TLines = TArray<string>;

function CreateStream(const AFilepath: string): TFileStream;

function WriteLines(const AFilepath: string; const ALines: TLines): Boolean;
function WriteBom(const AStream: TStream): Boolean;

implementation

function CreateStream(const AFilepath: string): TFileStream;
begin
  if FileExists(AFilepath) then
    Result := TFileStream.Create(AFilepath, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(AFilepath, fmCreate);
end;

function IsBom(const ABytes: TBytes): Boolean;
begin
  Result := (Length(ABytes) >= 3)
    and (ABytes[0] = $ef)
    and (ABytes[1] = $bb)
    and (ABytes[2] = $bf);
end;

function CreateBom: TBytes;
begin
  Result := [$EF, $BB, $BF];
end;

function WriteBom(const AStream: TStream): Boolean;
var
  BOM: TBytes;
  BUF: array[0..2] of byte = (0,0,0);
  Readed: LongInt;
begin
  if AStream.Size = 0 then
  begin
    Bom := CreateBom();
    AStream.WriteBuffer(BOM[0], Length(Bom));
    Result := True;
  end
  else
  begin
    AStream.Position := 0;
    SetLength(Bom, 3);
    FillChar(Bom[0], Length(Bom), 0);
    Readed := AStream.Read(Buf[0], 3);
    Result := IsBom(Bom);
  end;
  SetLength(Bom, 0);
end;

function WriteLines(const AFilepath: string; const ALines: TLines): Boolean;
var
  Buf: array[0..4095] of Byte;
  Stream: TFileStream;
  Line: string;
  I: Integer;
begin
  Result := False;

  Stream := CreateStream(AFilepath);
  if not Assigned(Stream) then
    Exit(False);

  FillChar(Buf[0], Sizeof(Buf), 0);
  try
    try
      if not WriteBom(Stream) then
        Stream.Position := 0;

      Stream.Position := Stream.Size;

      for I := 0 to Length(ALines) - 1 do
      begin
        Line := ALines[i] + sLineBreak;
        Stream.WriteBuffer(Line[1], Length(Line));
      end;

      Result := True;
    except
      on E: Exception do
      begin
        WriteLn(E.Classname, ': ', E.Message);
        Result := False;
      end;
    end;
  finally
    FreeAndNil(Stream);
  end;
end;

procedure LinesWrittenSuccessfull;
begin
  WriteLn('Success: Lines are written');
end;

procedure ErrorLinesNotWritten;
begin
  WriteLn('Error: lines not written');
end;

procedure TestFileOps;
var
  Lines: TLines;
  Filename: string;
begin
  Lines := [
    'first', 'second', 'third'
  ];
  Filename := 'test.txt';
  if WriteLines(Filename, Lines) then
    LinesWrittenSuccessfull()
  else
    ErrorLinesNotWritten();
end;

end.

