unit GlvLogFiles;

{$I 'glv_log_lib.inc'}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  Generics.Collections,
  GlvLogTypes,
  GlvLogBase;

type
  TAsyncLogThread = class(TThread)
  public type
    TLogRec = record
      Lvl: TLogLvl;
      Txt: string;
    end;

    TLogRecQueue = TQueue<TLogRec>;
  strict private
    FSync: TSynchroObject;
    FBuffer: TStringList;
    FQueue: TLogRecQueue;
    FFilepath: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AFilepath: string);
    destructor Destroy; override;

    procedure Log(const ALvl: TLogLvl; const ATxt: string);
  end;

  TAsyncFileLog = class(TLog)
  strict private
    FThread: TAsyncLogThread;
  public
    constructor Create(const AFilepath: UnicodeString); overload;
    constructor Create(const AThread: TAsyncLogThread); overload;
    destructor Destroy; override;
    procedure Log(const ALvl: TLogLvl; const ATxt: string); override;
  end;

  TDateTimeFunc = function: TDatetime;

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
    procedure Log(const ALvl: TLogLvl; const ATxt: string); override;
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
          FBuffer.Add(Format('[%s]: %s',[R.Lvl.AsStr, R.Txt]));
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
          Lines[I] := UTF8Decode(FBuffer[I]);
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
  FBuffer := TStringList.Create();
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
      Lines[I] := UTF8Decode(FBuffer[I]);
    end;
    WriteLines(FFilepath, Lines);
  end;
  FreeAndNil(FQueue);
  FreeAndNil(FBuffer);
  FreeAndNil(FSync);
  inherited Destroy;
end;

procedure TAsyncLogThread.Log(const ALvl: TLogLvl; const ATxt: string);
var
  R: TLogRec;
begin
  if Self.Suspended then
    Self.Suspended := False;

  FSync.Acquire;
  try
    R.Lvl := ALvl;
    R.Txt := ATxt;
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

procedure TAsyncFileLog.Log(const ALvl: TLogLvl; const ATxt: string);
begin
  FThread.Log(ALvl, ATxt);
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

procedure TPrimitiveFileLog.Log(const ALvl: TLogLvl; const ATxt: string);
var
  Items: TStringList;
  LevelStr: string;
begin
  LevelStr := Alvl.AsStr();

  FSync.Acquire;
  Items := TStringList.Create();
  try
    if FileExists(UTF8Encode(FFilename)) then
      Items.LoadFromFile(UTF8Encode(FFilename));

    Items.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', GetDatetime) + ' [' + LevelStr + '] ' + ATxt);
    Items.SaveToFile(UTF8Encode(FFilename));
  finally
    FreeAndNil(Items);
    FSync.Release;
  end;
end;

end.
