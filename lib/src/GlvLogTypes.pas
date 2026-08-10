unit GlvLogTypes;

{$I 'glv_log_lib.inc'}

interface

type
  TLogLvl = (llInfo, llDebug, llError, llWarn);

  TLogLvlHelper = record helper for TLogLvl
  public
    function AsStr: UnicodeString;
  end;

function LogLvlAsStr(const ALvl: TLogLvl): UnicodeString;

implementation

function LogLvlAsStr(const ALvl: TLogLvl): UnicodeString;
begin
  case ALvl of
    llDebug: Result := 'DEBUG';
    llInfo: Result := 'INFO';
    llWarn: Result  := 'WARN';
    llError: Result := 'ERROR';
    else Result := 'UNKNOWN';
  end;
end;

function TlogLvlHelper.AsStr: UnicodeString;
begin
  Result := LogLvlAsStr(Self);
end;

end.
