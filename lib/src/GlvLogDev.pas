{
 Module:       GlvLogDev
 Author:       GLV_off
 Description:  Developer level function's for logging.
 -             Not stable for public usage. Be warned!
 History:      2026-08-10: Created
}
unit GlvLogDev;

{$I 'glv_log_lib.inc'}

interface

uses
  GlvLogTypes;

{
 Log message with level
}
procedure DevLog(const Alvl: TLogLvl; const ATxt: string);

{
 Log formatted string message with level
}
procedure DevLogFmt(const Alvl: TLogLvl; const AFmt: string; const AItems: array of const);

{
 Wrapper for DebLog function with debug level
}
procedure DevLogDebug(const ATxt: string);

{
 Wrapper for DebLogFmt function with debug level
}
procedure DevLogDebugFmt(const AFmt: string; const AItems: array of const);

{
 Wrapper for DebLog function with info level
}
procedure DevLogInfo(const ATxt: string);

{
 Wrapper for DebLogFmt function with info level
}
procedure DevLogInfoFmt(const AFmt: string; const AItems: array of const);

{
 Wrapper for DebLog function with error level
}
procedure DevLogError(const ATxt: string);

{
 Wrapper for DebLogFmt function with error level
}
procedure DevLogErrorFmt(const AFmt: string; const AItems: array of const);

{
 Wrapper for DebLog function with debug level
}
procedure DevLogWarn(const ATxt: string);

{
 Wrapper for DebLogFmt function with debug level
}
procedure DevLogWarnFmt(const AFmt: string; const AItems: array of const);

implementation

procedure DevLog(const ALvl: TLogLvl; const ATxt: string);
begin
  WriteLn('[', ALvl.AsStr, '] ', ATxt);
end;

procedure DevLogFmt(const ALvl: TLogLvl; const AFmt: string; const AItems: array of const);
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

