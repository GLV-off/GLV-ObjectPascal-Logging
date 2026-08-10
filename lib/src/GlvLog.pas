unit GlvLog;

{$I 'glv_log_lib.inc'}

interface

uses
  GlvLogTypes,
  GlvLogBase,
  GlvLogCustom,
  GlvLogGroup,
  GlvLogFiles;

type
  TLogLvl = GlvLogTypes.TLogLvl;
  //TLogLvlHelper = GlvLogTypes.TLogLvlHelper;
  TLogCb = GlvLogCustom.TLogCb;

  TLog = GlvLogBase.TLog;
  TGroupLog = GlvLogGroup.TGroupLog;
  TCustomLog = GlvLogCustom.TCustomLog;
  TPrimitiveFileLog = GlvLogFiles.TPrimitiveFileLog;
  TAsyncFileLog = GlvLogFiles.TAsyncFileLog;

  TLogging = class
  strict private class var
    FInst: TLog;
  strict private
    class function GetLog: TLog; static;
    class procedure SetLog(const AValue: TLog); static;
  public
    class constructor Create;
    class destructor Destroy;

    class property Inst: TLog read GetLog write SetLog;
  end;

  TConsole = class
  public
    class procedure ConsoleLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
  end;

const
  LogLvlAsStr: function(const X: TLogLvl): UnicodeString = @GlvLogTypes.LogLvlAsStr;

implementation

uses
  SysUtils,
  Classes;

class function TLogging.GetLog: TLog;
begin
  Result := FInst;
end;

class procedure TLogging.SetLog(const AValue: TLog);
begin
  if Assigned(FInst) then
    FreeAndNil(FInst);
  FInst := AValue;
end;

class constructor TLogging.Create;
begin
  FInst := TGroupLog.Create([
    TCustomLog.Create(TConsole.ConsoleLog),
    TAsyncFileLog.Create(TAsyncLogThread.Create('log.log'))
  ]);
end;

class destructor TLogging.Destroy;
begin
  FreeAndNil(FInst);
end;

class procedure TConsole.ConsoleLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
begin
  WriteLn(ALvl.AsStr, ': t.id=', TThread.CurrentThread.ThreadID, ', m=', ATxt);
end;

end.

