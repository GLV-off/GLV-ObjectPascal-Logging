unit GLV.Log.SyncFileEngine;

{$I 'glv_log_lib.inc'}

interface

implementation

uses
  GLV.Log.Engine,
  GlvLog;

procedure SyncFileLog(const InLvl: TLogLvl; const InTxt: UnicodeString);
begin
  TLogging.Inst.Log(InLvl, InTxt);
end;

initialization

TLogging.Inst := TPrimitiveFileLog.Create('log.log');
TLogEngine.SetCb(@SyncFileLog);

end.

