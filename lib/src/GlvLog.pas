{
 Module:       GlvLog
 Author:       GLV_off
 Description:  Library facade unit. Includes and redeclares
 -             all common classes,types and routines
 -             for general usage.
 -             And for common user experience, contains single
 -             class singleton - Tlogging. Contains active at
 -             application logging configuration of object's.
 History:      2026-08-10: Created
}
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
  TLogCb = GlvLogCustom.TLogCb;

  TLog = GlvLogBase.TLog;
  TGroupLog = GlvLogGroup.TGroupLog;
  TCustomLog = GlvLogCustom.TCustomLog;
  TPrimitiveFileLog = GlvLogFiles.TPrimitiveFileLog;
  TAsyncFileLog = GlvLogFiles.TAsyncFileLog;

  {
   Logging singleton.

   By default contains one file logging object and
   custom logging object with console writing implementation
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
  end;

  {
   Technical object for console logging implementation.
  }
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

