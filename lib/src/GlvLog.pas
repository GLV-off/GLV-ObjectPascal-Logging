{
 Module:       GlvLog
 Author:       GLV_off
 Description:  Library facade unit. Includes and redeclares
 -             all common classes,types and routines
 -             for general usage.
 -             Kept for the V1 code base; new code is expected to use
 -             GLV.Log.* modules (GLV.Log.Builder, GLV.Log.Holder).
 History:      2026-08-10: Created
 -             2026-10-28: V1 Info/Warn/Error/Debug(+Fmt) procedures
 -                         removed, TConsole aliased to
 -                         GLV.Log.ConsoleSink, TLockLog/TLogBuilder
 -                         aliases added, TLogging marked deprecated
}
unit GlvLog;

{$I 'glv_log_lib.inc'}

interface

uses
  GLV.Log.Lvl,
  GLV.Log.ConsoleSink,
  GLV.Log.Lock,
  GLV.Log.Builder,
  GlvLogBase,
  GlvLogCustom,
  GlvLogGroup,
  GlvLogFiles;

type
  TLogLvl = GLV.Log.Lvl.TLogLvl;
  TLogCb = GlvLogCustom.TLogCb;

  TLog = GlvLogBase.TLog;
  TGroupLog = GlvLogGroup.TGroupLog;
  TCustomLog = GlvLogCustom.TCustomLog;
  TPrimitiveFileLog = GlvLogFiles.TPrimitiveFileLog;
  TAsyncFileLog = GlvLogFiles.TAsyncFileLog;
  TAsyncFileLogThread = GlvLogFiles.TAsyncLogThread;

  TConsole = GLV.Log.ConsoleSink.TConsole;
  TLockLog = GLV.Log.Lock.TLockLog;
  TLogBuilder = GLV.Log.Builder.TLogBuilder;

  {
   Logging singleton.

   By default contains one file logging object and
   custom logging object with console writing implementation

   Deprecated: V1 only. The singleton owns its graph and frees the
   previous one immediately on reassignment, so it cannot be hot-swapped
   safely from a worker thread. Use GLV.Log.Holder (V2) instead.
  }
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
  end deprecated;

const
  LogLvlAsStr: function(const X: TLogLvl): UnicodeString = @GLV.Log.Lvl.LogLvlAsStr;

implementation

uses
  SysUtils;

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

end.
