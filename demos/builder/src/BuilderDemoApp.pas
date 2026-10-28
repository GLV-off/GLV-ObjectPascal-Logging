{
 Module:       BuilderDemoApp
 Author:       GLV_off
 Description:  Runnable demo of GLV.Log.Builder.
 -             Shows a single sink, a fan-out group, the locking
 -             decorator, builder contract errors and reuse, and the
 -             V2 holder integration with a hot-swap. The async file
 -             scenario is opt-in because of the known defects in
 -             TAsyncLogThread.
 History:      2026-10-28: Created
}
unit BuilderDemoApp;

{$IFDEF FPC}
{$MODE DELPHI}
{$H+}
{$ENDIF FPC}

interface

{ Run every scenario. Returns 0 when all checks passed, 1 otherwise. }
function Run: Integer;

implementation

uses
  SysUtils,
  Classes,
  SyncObjs,
  GLV.Log,
  GLV.Log.Lvl,
  GLV.Log.Engine,
  GLV.Log.Builder,
  GLV.Log.Holder,
  GlvLogBase,
  GlvLogCustom,
  GlvLogFiles;

const
  CSyncLog = 'builder-sync.log';
  CDefaultLog = 'builder-default.log';
  CAsyncLog = 'builder-async.log';

  CDemoFiles: array[0..2] of string = (CSyncLog, CDefaultLog, CAsyncLog);

type
  { Holds demo state and prints the scenario output. }
  TBuilderDemo = class
  strict private
    FDir: string;
    FFailures: Integer;
    FWithAsync: Boolean;
    FCanCheckSyncFile: Boolean;
    FCanCheckDefaultFile: Boolean;
    FCountA: Integer;
    FCountB: Integer;
    function PathOf(const AName: string): string;
    procedure PrintHeader;
    procedure Section(const ATitle: string);
    procedure Check(const ACondition: Boolean; const AWhat: string);
    procedure CleanupFiles;
    procedure RunSingleSink;
    procedure RunFanOut;
    procedure RunLock;
    procedure RunContract;
    procedure RunHolder;
    procedure RunAsync;
    procedure HandleLogA(const ALvl: TLogLvl; const ATxt: UnicodeString);
    procedure HandleLogB(const ALvl: TLogLvl; const ATxt: UnicodeString);
  public
    constructor Create(const ADir: string; const AWithAsync: Boolean);
    function Run: Integer;
  end;

function FixedNow: TDateTime;
begin
  { Deterministic timestamp for the sync file scenario. }
  Result := EncodeDate(2026, 1, 2) + EncodeTime(3, 4, 5, 0);
end;

function CountLines(const AFileName: string): Integer;
var
  Lines: TStringList;
begin
  Result := -1;
  if not FileExists(AFileName) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    Result := Lines.Count;
  finally
    Lines.Free;
  end;
end;

function FirstLine(const AFileName: string): string;
var
  Lines: TStringList;
begin
  Result := '';
  if not FileExists(AFileName) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    if Lines.Count > 0 then
      Result := Lines[0];
  finally
    Lines.Free;
  end;
end;

procedure PrintUsage;
begin
  WriteLn('Usage: BuilderDemo [--async] [--wait] [--help]');
  WriteLn('  --async  also run the async file scenario (known defects)');
  WriteLn('  --wait   wait for Enter before exit');
  WriteLn('  --help   show this help and exit');
end;

constructor TBuilderDemo.Create(const ADir: string; const AWithAsync: Boolean);
begin
  inherited Create;
  FDir := ADir;
  if FDir = '' then
    FDir := GetCurrentDir;
  if (FDir <> '') and (FDir[Length(FDir)] <> PathDelim) then
    FDir := FDir + PathDelim;
  FWithAsync := AWithAsync;
  FFailures := 0;
  FCountA := 0;
  FCountB := 0;
end;

function TBuilderDemo.PathOf(const AName: string): string;
begin
  Result := FDir + AName;
end;

procedure TBuilderDemo.PrintHeader;
begin
  WriteLn('=== GLV.Log.Builder demo ===');
  WriteLn('Output directory: ', FDir);
  WriteLn('Only V2 units are used: GLV.Log, GLV.Log.Builder, GLV.Log.Holder');
  WriteLn;
  WriteLn('Scenarios: 1 single sink, 2 fan-out, 3 lock, 4 contract,');
  WriteLn('           5 V2 holder hot-swap, 6 async file (opt-in).');
end;

procedure TBuilderDemo.Section(const ATitle: string);
begin
  WriteLn;
  WriteLn('--- ', ATitle, ' ---');
end;

procedure TBuilderDemo.Check(const ACondition: Boolean; const AWhat: string);
begin
  if ACondition then
    WriteLn('  ok: ', AWhat)
  else
  begin
    WriteLn('  FAIL: ', AWhat);
    Inc(FFailures);
  end;
end;

procedure TBuilderDemo.CleanupFiles;
var
  I: Integer;
begin
  for I := Low(CDemoFiles) to High(CDemoFiles) do
    DeleteFile(PathOf(CDemoFiles[I]));
  FCanCheckSyncFile := not FileExists(PathOf(CSyncLog));
  FCanCheckDefaultFile := not FileExists(PathOf(CDefaultLog));
  if not FCanCheckSyncFile then
    WriteLn('  warning: cannot remove stale ', CSyncLog, ', file checks skipped');
  if not FCanCheckDefaultFile then
    WriteLn('  warning: cannot remove stale ', CDefaultLog, ', file checks skipped');
end;

procedure TBuilderDemo.HandleLogA(const ALvl: TLogLvl; const ATxt: UnicodeString);
begin
  Inc(FCountA);
  WriteLn('  [custom-A] ', LogLvlAsStr(ALvl), ': ', ATxt);
end;

procedure TBuilderDemo.HandleLogB(const ALvl: TLogLvl; const ATxt: UnicodeString);
begin
  Inc(FCountB);
  WriteLn('  [custom-B] ', LogLvlAsStr(ALvl), ': ', ATxt);
end;

procedure TBuilderDemo.RunSingleSink;
var
  B: TLogBuilder;
  L: TLog;
begin
  Section('1. one sink: Console');
  WriteLn('  B.Console.Build');
  B := TLogBuilder.Create;
  L := nil;
  try
    L := B.Console.Build;
    Check(Assigned(L), 'Build returned a graph');
    if Assigned(L) then
    begin
      Check(L.ClassName = 'TCustomLog', 'one sink is returned as is');
      L.Log(llInfo, 'single sink message');
    end;
  finally
    FreeAndNil(L);  { the caller owns a single sink }
    B.Free;
  end;
end;

procedure TBuilderDemo.RunFanOut;
var
  B: TLogBuilder;
  L: TLog;
  Line: string;
begin
  Section('2. fan-out: Console + sync file + two custom sinks');
  WriteLn('  B.Console.SyncFile(..., @FixedNow).Add(A).Add(B).Build');
  B := TLogBuilder.Create;
  L := nil;
  try
    B.Console
      .SyncFile(UnicodeString(PathOf(CSyncLog)), @FixedNow)
      .Add(TCustomLog.Create(HandleLogA))
      .Add(TCustomLog.Create(HandleLogB));
    L := B.Build;
    Check(Assigned(L), 'Build returned a graph');
    if Assigned(L) then
    begin
      Check(L.ClassName = 'TGroupLog', 'several sinks are merged into TGroupLog');
      L.Log(llInfo, 'fan-out: info');
      L.Log(llWarn, 'fan-out: warn');
      L.Log(llError, 'fan-out: error');
      L.Log(llDebug, 'fan-out: debug');
    end;
  finally
    FreeAndNil(L);  { after Build the group owns all sinks }
    B.Free;
  end;
  Check(FCanCheckSyncFile and (CountLines(PathOf(CSyncLog)) = 4),
    'sync file has 4 lines');
  if FCanCheckSyncFile then
  begin
    Line := FirstLine(PathOf(CSyncLog));
    WriteLn('  first line: ', Line);
    Check(Pos('2026-01-02 03:04:05 [INFO] fan-out: info', Line) > 0,
      'sync file uses the injected clock and the V1 file format');
  end;
end;

procedure TBuilderDemo.RunLock;
var
  B: TLogBuilder;
  L: TLog;
  CS: TCriticalSection;
begin
  Section('3. lock: WithLock');
  WriteLn('  B.Console.WithLock().Build  (TLockLog owns a TCriticalSection)');
  B := TLogBuilder.Create;
  L := nil;
  try
    L := B.Console.WithLock().Build;
    Check(Assigned(L), 'Build returned a graph');
    if Assigned(L) then
    begin
      Check(L.ClassName = 'TLockLog', 'the whole graph is wrapped in TLockLog');
      L.Log(llWarn, 'locked message with an owned lock');
    end;
  finally
    FreeAndNil(L);  { TLockLog frees the inner sink and its own lock }
    B.Free;
  end;

  WriteLn('  B.Console.WithLock(CS).Build  (CS is borrowed, not freed)');
  CS := TCriticalSection.Create;
  try
    B := TLogBuilder.Create;
    L := nil;
    try
      L := B.Console.WithLock(CS).Build;
      Check(Assigned(L), 'Build returned a graph with a borrowed lock');
      if Assigned(L) then
        L.Log(llInfo, 'locked message with a borrowed lock');
    finally
      FreeAndNil(L);  { TLockLog frees the inner sink, not the borrowed CS }
      B.Free;
    end;
    CS.Acquire;
    try
      Check(True, 'borrowed lock is still usable after the graph is freed');
    finally
      CS.Release;
    end;
  finally
    CS.Free;
  end;
end;

procedure TBuilderDemo.RunContract;
var
  B: TLogBuilder;
  L: TLog;
  Line: string;
begin
  Section('4. builder contract: errors, consumption, reuse');
  B := TLogBuilder.Create;
  L := nil;
  try
    WriteLn('  empty builder:');
    try
      B.Build;
      Check(False, 'empty builder raises ELogBuilderError');
    except
      on E: ELogBuilderError do
        Check(True, 'empty builder: ' + E.Message);
    end;

    WriteLn('  Add(nil):');
    try
      B.Add(nil);
      Check(False, 'Add(nil) raises ELogBuilderError');
    except
      on E: ELogBuilderError do
        Check(True, 'Add(nil): ' + E.Message);
    end;

    WriteLn('  B.SyncFile(...).Build  (default clock overload)');
    L := B.SyncFile(UnicodeString(PathOf(CDefaultLog))).Build;
    Check(Assigned(L), 'Build after errors returned a graph');
    if Assigned(L) then
    begin
      Check(L.ClassName = 'TPrimitiveFileLog',
        'SyncFile without a clock returns TPrimitiveFileLog');
      L.Log(llInfo, 'default clock message');
    end;

    WriteLn('  second Build without new sinks:');
    try
      B.Build;
      Check(False, 'Build consumes the configuration');
    except
      on E: ELogBuilderError do
        Check(True, 'Build consumed the configuration: ' + E.Message);
    end;
  finally
    FreeAndNil(L);
    B.Free;
  end;
  Check(FCanCheckDefaultFile and (CountLines(PathOf(CDefaultLog)) = 1),
    'default file has 1 line');
  if FCanCheckDefaultFile then
  begin
    Line := FirstLine(PathOf(CDefaultLog));
    WriteLn('  first line: ', Line);
    Check(Pos('[INFO] default clock message', Line) > 0,
      'default file uses the V1 format');
  end;
end;

procedure TBuilderDemo.RunHolder;
var
  B: TLogBuilder;
  G1, G2: TLog;
begin
  Section('5. V2 integration: TLogHolder hot-swap');
  WriteLn('  TLogHolder.Inst := B.Console.Add(custom-A).Build');
  B := TLogBuilder.Create;
  G1 := nil;
  try
    G1 := B.Console.Add(TCustomLog.Create(HandleLogA)).Build;
  finally
    B.Free;
  end;
  TLogHolder.Inst := G1;  { the holder owns G1 now }
  FCountA := 0;
  FCountB := 0;
  LogInfo('holder: info before swap');
  LogWarn('holder: warn before swap');
  Check(FCountA > 0, 'messages reached the first graph');

  WriteLn('  TLogHolder.Inst := B.Console.Add(custom-B).Build  (hot-swap)');
  B := TLogBuilder.Create;
  G2 := nil;
  try
    G2 := B.Console.Add(TCustomLog.Create(HandleLogB)).Build;
  finally
    B.Free;
  end;
  TLogHolder.Inst := G2;  { G1 is retired, not freed }
  FCountA := 0;
  FCountB := 0;
  LogError('holder: error after swap');
  Check(TLogHolder.Inst = G2, 'the second graph is active');
  Check(FCountB > 0, 'messages reached the second graph');
  Check(FCountA = 0, 'the retired graph does not receive new messages');

  WriteLn('  TLogHolder.Inst := nil  (logging is disabled)');
  TLogHolder.Inst := nil;
  try
    LogDebug('holder: must not appear');
    Check(False, 'Inst := nil disables logging');
  except
    on E: ELoggingEngineNotInitialized do
      Check(True, 'Inst := nil disables logging: ' + E.ClassName);
  end;
  WriteLn('  G1/G2 are not freed here: TLogHolder owns them until finalization.');
end;

procedure TBuilderDemo.RunAsync;
var
  B: TLogBuilder;
  L: TLog;
begin
  Section('6. async file: Console + AsyncFile');
  WriteLn('  known defects BL-001/BL-002: the thread spins, rewrites the file');
  WriteLn('  and may lose queued records, so the file content is not checked.');
  B := TLogBuilder.Create;
  L := nil;
  try
    L := B.Console.AsyncFile(UnicodeString(PathOf(CAsyncLog))).Build;
    Check(Assigned(L), 'Build returned a graph');
    if Assigned(L) then
    begin
      Check(L.ClassName = 'TGroupLog', 'Console + AsyncFile are merged');
      L.Log(llInfo, 'async message');
      Sleep(200);  { demo delay only, not a correctness assertion }
    end;
  finally
    FreeAndNil(L);  { TAsyncFileLog.Destroy stops the thread }
    B.Free;
  end;
  WriteLn('  async graph stopped');
end;

function TBuilderDemo.Run: Integer;
begin
  PrintHeader;
  CleanupFiles;
  RunSingleSink;
  RunFanOut;
  RunLock;
  RunContract;
  RunHolder;
  if FWithAsync then
    RunAsync
  else
  begin
    Section('6. async file (skipped)');
    WriteLn('  run with --async to build a graph with TAsyncFileLog');
    WriteLn('  known defects BL-001/BL-002: the thread spins, rewrites the file');
    WriteLn('  and may lose queued records, so the file content is not checked.');
  end;
  WriteLn;
  if FFailures = 0 then
  begin
    WriteLn('RESULT: PASS');
    Result := 0;
  end
  else
  begin
    WriteLn('RESULT: FAIL (', FFailures, ' check(s))');
    Result := 1;
  end;
end;

function Run: Integer;
var
  App: TBuilderDemo;
  WithAsync: Boolean;
  ShouldWait: Boolean;
  I: Integer;
  Arg: string;
begin
  WithAsync := False;
  ShouldWait := False;
  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);
    if Arg = '--async' then
      WithAsync := True
    else if Arg = '--wait' then
      ShouldWait := True
    else if Arg = '--help' then
    begin
      PrintUsage;
      Result := 0;
      Exit;
    end
    else
    begin
      WriteLn('Unknown option: ', Arg);
      PrintUsage;
      Result := 2;
      Exit;
    end;
  end;

  App := TBuilderDemo.Create(ExtractFilePath(ParamStr(0)), WithAsync);
  try
    try
      Result := App.Run;
    except
      on E: Exception do
      begin
        WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
        Result := 1;
      end;
    end;
  finally
    App.Free;
  end;

  if ShouldWait then
  begin
    WriteLn('Press Enter to close...');
    ReadLn;
  end;
end;

end.
