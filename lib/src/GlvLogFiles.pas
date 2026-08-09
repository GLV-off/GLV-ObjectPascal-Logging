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
    constructor Create(const AThread: TAsyncLogThread);
    destructor Destroy; override;
    procedure Log(const ALvl: TLogLvl; const ATxt: string); override;
  end;

  TPrimitiveFileLog = class(TLog)
  strict private
    FFilename: string;
    FSync: TSynchroObject;
  public
    constructor Create(const AFilename: string);
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
            break;
          //DevLogDebugFmt('[before deq] queue.count = %d', [FQueue.Count]);
          R := FQueue.Dequeue();
          //DevLogDebugFmt('[after  deq]queue.count = %d', [FQueue.Count]);
          FBuffer.Insert(0, Format('[%s]: %s',[R.Lvl.AsStr, R.Txt]));
          //DevLogDebugFmt('[after insert] queue.count = %d', [FQueue.Count]);
          Dec(C);
        end;
      end
      else
      begin
        //Suspended := True;
      end;
    finally
      FSync.Release();
    end;

    FSync.Acquire();
    try
      if FBuffer.Count >= 0 then
      begin
        WriteLines(FFilepath, FBUffer.ToStringArray());
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
begin
  if FBuffer.Count > 0 then
    WriteLines(FFilepath, FBUffer.ToStringArray());
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

constructor TPrimitiveFileLog.Create(const AFilename: string);
begin
  inherited Create;
  FFilename := AFilename;
  FSync := TCriticalSection.Create;
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
    if FileExists(FFilename) then
      Items.LoadFromFile(FFilename);

    Items.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' [' + LevelStr + '] ' + ATxt);
    Items.SaveToFile(FFilename);
  finally
    FreeAndNil(Items);
    FSync.Release;
  end;
end;

end.
