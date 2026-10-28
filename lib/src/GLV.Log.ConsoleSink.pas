{
 Module:       GLV.Log.ConsoleSink
 Author:       GLV_off
 Description:  Console sink implementation for V2 logging graphs.
 -             Extracted from the V1 facade (GlvLog.TConsole) so that
 -             GLV.Log.Builder can build a console sink without
 -             depending on the facade unit.
 History:      2026-10-28: Created
}
unit GLV.Log.ConsoleSink;

{$I 'glv_log_lib.inc'}

interface

uses
  GLV.Log.Lvl;

type
  {
   Technical object for console logging implementation.

   Pass TConsole.ConsoleLog as a TLogCb callback to TCustomLog
   (directly or via TLogBuilder.Console).
  }
  TConsole = class
  public
    {
     Write one message to stdout in the legacy V1 format:
     LEVEL: t.id=<ThreadID>, m=<text>
    }
    class procedure ConsoleLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
  end;

implementation

uses
  Classes;

class procedure TConsole.ConsoleLog(const ALvl: TLogLvl;
  const ATxt: UnicodeString);
begin
  WriteLn(ALvl.AsStr, ': t.id=', TThread.CurrentThread.ThreadID, ', m=', ATxt);
end;

end.
