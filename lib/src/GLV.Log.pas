{
 Module:       GLV.Log
 Author:       GLV_off
 Description:  Basic types of logging library.
 History:      2026-08-10: Created
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

