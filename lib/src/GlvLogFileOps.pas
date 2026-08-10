unit GlvLogFileOps;

{$I 'glv_log_lib.inc'}

interface

uses
  Classes,
  SysUtils;

procedure TestFileOps;

type
  TLines = TArray<UnicodeString>;

function CreateStream(const AFilepath: string): TFileStream;

function WriteLines(const AFilepath: string; const ALines: TLines): Boolean;

implementation

{
 Writing BOM bytes header in stream. It will not sugest thath
 stream already contain's writen bom, so use carefully. Not
 intended for public usage.
}
function WriteBom(const AStream: TStream): Boolean; forward;

function CreateStream(const AFilepath: string): TFileStream;
{ Creating file stream for writing operations.
  If File exists - it create stream as reading
  If File not exists - it creates stream as file will be
  created before or after writing. }
var
  Mask: Word;
begin
  if FileExists(AFilepath) then
    Mask := fmOpenReadWrite or fmShareDenyNone
  else
    Mask := fmCreate;

  Result := TFileStream.Create(AFilepath, Mask)
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
  BUF: array[0..2] of byte = (0, 0, 0);
  Readed: LongInt;
begin
  try
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
      Result := IsBom(Bom) and (Readed > 0);
    end;
  finally
    SetLength(Bom, 0);
  end;
end;

function WriteLines(const AFilepath: string; const ALines: TLines): Boolean;
{ Write lines( array of strings) into file at `AFilepath`
  THis routine save text in UTF-8 encoding with BOM.
  @param AFIlepath Filepath to save lines. }
type
  TBuf = array[0..4095] of Byte;
var
  Buf: TBuf;
  Stream: TFileStream;
  Line: string;
  I: Integer;
begin
  Result := False;

  Stream := CreateStream(AFilepath);
  if not Assigned(Stream) then
    Exit(False);

  Buf := Default(TBuf);
  FillChar(Buf[0], Sizeof(Buf), 0);
  try
    try
      if not WriteBom(Stream) then
        Stream.Position := 0;

      Stream.Position := 0;

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

