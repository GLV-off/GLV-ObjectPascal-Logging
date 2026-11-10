{
 Module:       GLV.Log
 Author:       GLV_off
 Description:  Basic types of logging library.
 History:      2026-08-10: Created
               2026-11-06: AnsiString overloads (FPC UTF-8 BOM literal workaround)
}
unit GLV.Log;

{$I 'glv_log_lib.inc'}

interface

uses
  GLV.Log.Lvl,
  GLV.Log.Engine;

const
  llInfo = GLV.Log.Lvl.TLoglvl.llInfo;
  llError = GLV.Log.Lvl.TLoglvl.llError;
  llWarn = GLV.Log.Lvl.TLoglvl.llWarn;
  llDebug = GLV.Log.Lvl.TLoglvl.llDebug;

type
  TLogLvl = GLV.Log.Lvl.TLogLvl;
  TLogEngine = GLV.Log.Engine.TLogEngine;
  TLogEngineCallback = GLV.Log.Engine.TLogEngineCallback;

{
 Main text procedures. Text is UnicodeString and is passed to the engine
 as is.
}
procedure LogInfo(const InTxt: UnicodeString); overload;
procedure LogError(const InTxt: UnicodeString); overload;
procedure LogWarn(const InTxt: UnicodeString); overload;
procedure LogDebug(const InTxt: UnicodeString); overload;
{$IFDEF FPC}
{
 AnsiString overloads. Workaround for the FPC compiler: string literals
 from sources saved as UTF-8 with BOM are converted to UnicodeString at
 compile time and lose their last character (the constant is emitted
 with Length = real - 1). A literal is an AnsiString, so it is routed
 here and converted at run time, where the conversion is correct.
}
procedure LogInfo(const InTxt: AnsiString); overload;
procedure LogError(const InTxt: AnsiString); overload;
procedure LogWarn(const InTxt: AnsiString); overload;
procedure LogDebug(const InTxt: AnsiString); overload;
{$ENDIF FPC}
procedure LogInfoFmt(const InFmt: UnicodeString; const InArgs: array of const);
procedure LogErrorFmt(const InFmt: UnicodeString; const InArgs: array of const);
procedure LogWarnFmt(const InFmt: UnicodeString; const InArgs: array of const);
procedure LogDebugFmt(const InFmt: UnicodeString; const InArgs: array of const);

implementation

uses
  StrUtils,
  SysUtils;

procedure LogInfo(const InTxt: UnicodeString);
begin
  TLogEngine.Call(TLogLvl.llInfo, InTxt);
end;

procedure LogError(const InTxt: UnicodeString);
begin
  TLogEngine.Call(TLogLvl.llError, InTxt);
end;

procedure LogWarn(const InTxt: UnicodeString);
begin
  TLogEngine.Call(TLogLvl.llWarn, InTxt);
end;

procedure LogDebug(const InTxt: UnicodeString);
begin
  TLogEngine.Call(TLogLvl.llDebug, InTxt);
end;

{$IFDEF FPC}
procedure LogInfo(const InTxt: AnsiString);
var
  Txt: UnicodeString;
begin
  Txt := UnicodeString(InTxt);
  LogInfo(Txt);
end;

procedure LogError(const InTxt: AnsiString);
var
  Txt: UnicodeString;
begin
  Txt := UnicodeString(InTxt);
  LogError(Txt);
end;

procedure LogWarn(const InTxt: AnsiString);
var
  Txt: UnicodeString;
begin
  Txt := UnicodeString(InTxt);
  LogWarn(Txt);
end;

procedure LogDebug(const InTxt: AnsiString);
var
  Txt: UnicodeString;
begin
  Txt := UnicodeString(InTxt);
  LogDebug(Txt);
end;
{$ENDIF FPC}

function FormatWrapper(const InFmt: UnicodeString; const InArgs: array of const): UnicodeString;
begin
{$IFDEF FPC}
  Result := UnicodeFormat(InFmt, InArgs);
{$ELSE FPC}
  Result := Format(InFmt, InArgs);
{$ENDIF FPC}
end;

procedure LogInfoFmt(const InFmt: UnicodeString; const InArgs: array of const);
begin
  TLogEngine.Call(TLogLvl.llInfo, FormatWrapper(InFmt, InArgs));
end;

procedure LogErrorFmt(const InFmt: UnicodeString; const InArgs: array of const);
begin
  TLogEngine.Call(TLogLvl.llError, FormatWrapper(InFmt, InArgs));
end;

procedure LogWarnFmt(const InFmt: UnicodeString; const InArgs: array of const);
begin
  TLogEngine.Call(TLogLvl.llWarn, FormatWrapper(InFmt, InArgs));
end;

procedure LogDebugFmt(const InFmt: UnicodeString; const InArgs: array of const);
begin
  TLogEngine.Call(TLogLvl.llDebug, FormatWrapper(InFmt, InArgs));
end;

end.

