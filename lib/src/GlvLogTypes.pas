unit GlvLogTypes;

{$I 'glv_log_lib.inc'}

interface

type
  TLogLvl = (llInfo, llDebug, llError, llWarn);

  TLogLvlHelper = record helper for TLogLvl
  public
    function AsStr: string;
  end;

implementation

function TlogLvlHelper.AsStr: string;
begin
  case Self of
    llDebug: Result := 'DEBUG';
    llInfo: Result := 'INFO';
    llWarn: Result  := 'WARN';
    llError: Result := 'ERROR';
    else Result := 'UNKNOWN';
  end;
end;

end.