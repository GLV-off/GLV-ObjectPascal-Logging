{
 Module:       GlvLogContract
 Author:       GLV_off
 Description:
 History:      2026-10-28: Created
}
unit GlvLogContract;

{$I 'glv_log_lib.inc'}

interface

uses
  GlvLogTypes,
  GlvLogEngine;

const
  llInfo = GlvLogTypes.TLoglvl.llInfo;
  llError = GlvLogTypes.TLoglvl.llError;
  llWarn = GlvLogTypes.TLoglvl.llWarn;
  llDebug = GlvLogTypes.TLoglvl.llDebug;

type
  TLogLvl = GlvLogTypes.TLogLvl;
  TLogEngine = GlvLogEngine.TLogEngine;
  TLogEngineCallback = GlvLogEngine.TLogEngineCallback;

procedure LogInfo(const InTxt: UnicodeString);
procedure LogError(const InTxt: UnicodeString);
procedure LogWarn(const InTxt: UnicodeString);
procedure LogDebug(const InTxt: UnicodeString);

implementation

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

end.
