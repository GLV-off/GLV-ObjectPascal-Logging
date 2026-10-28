{
 Module:       GlvLogFiles
 Author:       GLV_off
 Description:  Collection of file logger's. One sync and one
 -             async implementation (with separated
 -             single thread).
 History:      2026-08-10: Created
}
unit GlvLogFiles;

{$I 'glv_log_lib.inc'}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  Generics.Collections,
  GLV.Log.Lvl,
  GlvLogBase;

type
  {
   Async Logging thread used in TAsyncFileLog class
   as implementation of delayed background filewrite
   operation controll.
  }
  TAsyncLogThread = class(TThread)
  public type
    TLogRec = record
      Lvl: TLogLvl;
      Txt: UnicodeString;
    end;

    TLogRecQueue = TQueue<TLogRec>;
  strict private
    FSync: TSynchroObject;
    { Buffer of already formatted lines. UnicodeString is used to
      avoid lossy AnsiString round-trips inside the thread. }
    FBuffer: TList<UnicodeString>;
    FQueue: TLogRecQueue;
    FFilepath: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AFilepath: string);
    destructor Destroy; override;

    procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString);
  end;

  {
   Async file loggger

   Main control point of async logging. Delegate
   logging procedure to its encapsulated thread.
  }
  TAsyncFileLog = class(TLog)
  strict private
    FThread: TAsyncLogThread;
  public
    constructor Create(const AFilepath: UnicodeString); overload;
    constructor Create(const AThread: TAsyncLogThread); overload;
    destructor Destroy; override;
    procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); override;
  end;

  {
   Function that can return value of TDatetime data type.

   Mainly used in sync (currently) logging as
   routine abstraction for logic of generating datetime.
  }
  TDateTimeFunc = function: TDatetime;

  {
   Synchronus file logging object

   Writes in file as logging operation accures.

   Before real logging reads all file in memory and
   appends it's text to buffer and rewrite file.

   Not thread safe at this point.
  }
  TPrimitiveFileLog = class(TLog)
  strict private
    FFilename: UnicodeString;
    FSync: TSynchroObject;
    FDateTimeFunc: TDateTimeFunc;
    function GetDatetime: TDatetime;
  public
    constructor Create(const AFilename: UnicodeString; const ADateTimeFunc: TDateTimeFunc); overload;
    constructor Create(const AFilename: UnicodeString); overload;
    destructor Destroy; override;
    procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); override;
  end;

implementation

uses
  GlvLogFileOps;

procedure TAsyncLogThread.Execute;
var
  R: TLogRec;
  C: LongInt;
  Lines: TArray<UnicodeString>;
  I: LongInt;
begin
  while not Terminated do
  begin
    FSync.Acquire();
    try
      { Сбрасывать в файл каждые 8 записей }
      if FQueue.Count > 0 then
      begin
        C := FQueue.Count;
        while C > 0 do
        begin
          if Terminated then
            Break;
          R := FQueue.Dequeue();
          //FBuffer.Insert(0, Format('[%s]: %s',[R.Lvl.AsStr, R.Txt]));
          { Concatenation instead of Format: FPC's Format works via
            AnsiString and would silently lose non-ASCII text. }
          FBuffer.Add('[' + R.Lvl.AsStr + ']: ' + R.Txt);
          Dec(C);
        end;
      end;
    finally
      FSync.Release();
    end;

    FSync.Acquire();
    try
      if FBuffer.Count >= 0 then
      begin
        Lines := [];
        SetLength(Lines, FBuffer.Count);
        for I := 0 to FBuffer.Count - 1 do
        begin
          Lines[I] := FBuffer[I];
        end;
        WriteLines(FFilepath, Lines);
        SetLength(Lines, 0);
        FBuffer.Clear();
      end;
    finally
      FSync.Release();
    end;

    if (FBUffer.Count = 0) and (FQueue.Count = 0) then
      SUspended := True;
  end;
end;

constructor TAsyncLogThread.Create(const AFilepath: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;

  FSync := TCriticalSection.Create;
  FBuffer := TList<UnicodeString>.Create();
  FBuffer.Clear;
  FQueue := TLogRecQueue.Create;
  FQueue.Clear;
  FFilepath := AFilepath;
end;

destructor TAsyncLogThread.Destroy;
var
  Lines: TLines;
  I: LongInt;
begin
  if FBuffer.Count > 0 then
  begin
    Lines := [];
    SetLength(Lines, FBuffer.Count);
    for I := 0 to FBuffer.Count - 1 do
    begin
      Lines[I] := FBuffer[I];
    end;
    WriteLines(FFilepath, Lines);
  end;
  FreeAndNil(FQueue);
  FreeAndNil(FBuffer);
  FreeAndNil(FSync);
  inherited Destroy;
end;

procedure TAsyncLogThread.Log(const InLvl: TLogLvl; const InTxt: UnicodeString);
var
  R: TLogRec;
begin
  if Self.Suspended then
    Self.Suspended := False;

  FSync.Acquire;
  try
    R.Lvl := InLvl;
    R.Txt := InTxt;
    FQueue.Enqueue(R);
  finally
    FSync.Release;
  end;
end;

constructor TAsyncFileLog.Create(const AFilepath: UnicodeString);
begin
  Self.Create(TAsyncLogThread.Create(AFilepath));
end;

constructor TAsyncFileLog.Create(const AThread: TAsyncLogThread);
begin
  inherited Create;
  FThread := AThread;
end;

destructor TAsyncFileLog.Destroy;
begin
  FTHread.Terminate;
  if FTHread.Suspended then
    FTHread.Suspended := False;
  FThread.WaitFor;
  FreeAndNil(FThread);
  inherited Destroy;
end;

procedure TAsyncFileLog.Log(const InLvl: TLogLvl; const InTxt: UnicodeString);
begin
  FThread.Log(InLvl, InTxt);
end;

function TPrimitiveFileLog.GetDatetime: TDatetime;
begin
  if ASsigned(FDateTimeFunc) then
    Result := FDateTimeFunc
  else
    Result := Now;
end;

constructor TPrimitiveFileLog.Create(const AFilename: UnicodeString; const ADateTimeFunc: TDateTimeFunc);
begin
  inherited Create;
  FFilename := AFilename;
  FSync := TCriticalSection.Create;
  FDateTimeFunc:= ADateTimeFunc;
end;

constructor TPrimitiveFileLog.Create(const AFilename: UnicodeString);
begin
  Self.Create(AFilename, @Now);
end;

destructor TPrimitiveFileLog.Destroy;
begin
  FreeAndNil(FSync);
  FFilename := '';
  inherited Destroy;
end;

procedure TPrimitiveFileLog.Log(const InLvl: TLogLvl; const InTxt: UnicodeString);
var
  Items: TStringList;
  LevelStr: UnicodeString;
begin
  LevelStr := InLvl.AsStr();

  FSync.Acquire;
  Items := TStringList.Create();
  try
    if FileExists(UTF8Encode(FFilename)) then
      Items.LoadFromFile(UTF8Encode(FFilename));

    { UTF8Encode keeps the file UTF-8: an implicit UnicodeString ->
      AnsiString conversion would encode to DefaultSystemCodePage. }
    Items.Add(UTF8Encode(FormatDateTime('yyyy-mm-dd hh:nn:ss', GetDatetime) + ' [' + LevelStr + '] ' + InTxt));
    Items.SaveToFile(UTF8Encode(FFilename));
  finally
    FreeAndNil(Items);
    FSync.Release;
  end;
end;

end.
