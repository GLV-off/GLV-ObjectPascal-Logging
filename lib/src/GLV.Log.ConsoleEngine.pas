unit GLV.Log.ConsoleEngine;

{$I 'glv_log_lib.inc'}

interface

implementation

uses
  SysUtils,
  Classes,
  GLV.Log.Lvl,
  GLV.Log.Engine;

class procedure ConsoleLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
begin
  WriteLn(ALvl.AsStr, ': t.id=', TThread.CurrentThread.ThreadID, ', m=', ATxt);
end;

initialization

TLogEngine.SetCb(@ConsoleLog);

end.

