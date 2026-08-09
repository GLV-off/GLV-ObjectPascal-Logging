unit GlvLogDev;

{$I 'glv_log_lib.inc'}

interface

uses
  GlvLogTypes;

procedure DevLog(const Alvl: TLogLvl; const ATxt: string);
procedure DevLogFmt(const Alvl: TLogLvl; const AFmt: string; const AItems: array of const);

procedure DevLogDebug(const ATxt: string);
procedure DevLogDebugFmt(const AFmt: string; const AItems: array of const);

procedure DevLogInfo(const ATxt: string);
procedure DevLogInfoFmt(const AFmt: string; const AItems: array of const);

procedure DevLogError(const ATxt: string);
procedure DevLogErrorFmt(const AFmt: string; const AItems: array of const);

procedure DevLogWarn(const ATxt: string);
procedure DevLogWarnFmt(const AFmt: string; const AItems: array of const);

implementation

procedure DevLog(const Alvl: TLogLvl; const ATxt: string);
begin
  WriteLn('[', ALvl.AsStr, '] ', ATxt);
end;

procedure DevLogFmt(const Alvl: TLogLvl; const AFmt: string; const AItems: array of const);
begin
  DevLog(ALvl, Format(AFmt, AItems));
end;

procedure DevLogDebug(const ATxt: string);
begin
  DevLog(llDebug, ATxt);
end;

procedure DevLogDebugFmt(const AFmt: string; const AItems: array of const);
begin
  DevLogFmt(llDebug, AFmt, AItems);
end;

procedure DevLogInfo(const ATxt: string);
begin
  DevLog(llInfo, ATxt);
end;

procedure DevLogInfoFmt(const AFmt: string; const AItems: array of const);
begin
  DevLogFmt(llInfo, AFmt, AItems);
end;

procedure DevLogError(const ATxt: string);
begin
  DevLog(llError, ATxt);
end;

procedure DevLogErrorFmt(const AFmt: string; const AItems: array of const);
begin
  DevLogFmt(llError, AFmt, AItems);
end;

procedure DevLogWarn(const ATxt: string);
begin
  DevLog(llWarn, ATxt);
end;

procedure DevLogWarnFmt(const AFmt: string; const AItems: array of const);
begin
  DevLogFmt(llWarn, AFmt, AItems);
end;

end.

