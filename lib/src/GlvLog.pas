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
  GLV.Log.Lvl,
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
  LogLvlAsStr: function(const X: TLogLvl): UnicodeString = @GLV.Log.Lvl.LogLvlAsStr;

procedure Info(const ATxt: UnicodeString);
procedure Warn(const ATxt: UnicodeString);
procedure Error(const ATxt: UnicodeString);
procedure Debug(const ATxt: UnicodeString);

procedure InfoFmt(const InFmt: string; const InArgs: array of const);
procedure WarnFmt(const InFmt: string; const InArgs: array of const);
procedure ErrorFmt(const InFmt: string; const InArgs: array of const);
procedure DebugFmt(const InFmt: string; const InArgs: array of const);

implementation

uses
  SysUtils,
  Classes;

procedure Info(const ATxt: UnicodeString);
begin
  TLogging.Inst.Log(TLogLvl.llInfo, ATxt);
end;

procedure Warn(const ATxt: UnicodeString);
begin
  TLogging.Inst.Log(TLogLvl.llWarn, ATxt);
end;

procedure Error(const ATxt: UnicodeString);
begin
  TLogging.Inst.Log(TLogLvl.llError, ATxt);
end;

procedure Debug(const ATxt: UnicodeString);
begin
  TLogging.Inst.Log(TLogLvl.llDebug, ATxt);
end;

procedure InfoFmt(const InFmt: string; const InArgs: array of const);
begin
  TLogging.Inst.Log(TLogLvl.llInfo, Format(InFmt, InArgs));
end;

procedure WarnFmt(const InFmt: string; const InArgs: array of const);
begin
  TLogging.Inst.Log(TLogLvl.llWarn, Format(InFmt, InArgs));
end;

procedure ErrorFmt(const InFmt: string; const InArgs: array of const);
begin
  TLogging.Inst.Log(TLogLvl.llError, Format(InFmt, InArgs));
end;

procedure DebugFmt(const InFmt: string; const InArgs: array of const);
begin
  TLogging.Inst.Log(TLogLvl.llDebug, Format(InFmt, InArgs));
end;

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

