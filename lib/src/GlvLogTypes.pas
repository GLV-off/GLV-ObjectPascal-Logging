{
 Module:       GlvLogTypes
 Author:       GLV_off
 Description:  Basic types of logging library.
 History:      2026-08-10: Created
}
unit GlvLogTypes;

{$I 'glv_log_lib.inc'}

interface

type
  {
   Type declares level of logging wich
   linked single message:

   llInfo    Information
   llDebug   Debug message
   llError   Error message
   llWarn    Warning message
  }
  TLogLvl = (llInfo, llDebug, llError, llWarn);

  {
   Type helper for Log Level enumeration
  }
  TLogLvlHelper = record helper for TLogLvl
  public
    {
     Convert enumeration value to string as
     helper method
    }
    function AsStr: UnicodeString;
  end;

{
 Converting enumeration value to string. Return value
 will be full UPPERCASE one word string value without
 enumeration prefixes.
}
function LogLvlAsStr(const ALvl: TLogLvl): UnicodeString;

implementation

function LogLvlAsStr(const ALvl: TLogLvl): UnicodeString;
{ Converting enumeration value to string. Return value
  will be full UPPERCASE one word string value without
  enumeration prefixes. }
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
{ Convert enumeration value to string as
  helper method }
begin
  Result := LogLvlAsStr(Self);
end;

end.
