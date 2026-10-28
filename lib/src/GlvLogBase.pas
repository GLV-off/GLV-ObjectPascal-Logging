{
 Module:       GlvLogBase
 Author:       GLV_off
 Description:  Basic abstraction of logging object implementations.
 -             Declare public interface of how use logging.
 History:      2026-08-10: Created
}
unit GlvLogBase;

{$I 'glv_log_lib.inc'}

interface

uses
  GLV.Log.Lvl;

type
  {
   Basic logging abstraction.

   All subclasses should implement single method - Log
  }
  TLog = class abstract(TInterfacedObject)
  public
    {
     Log text message with specifed log level.

     Text is passed as UnicodeString. Encoding to bytes (UTF-8 for
     file loggers) is up to the concrete implementation, so no
     AnsiString <-> UnicodeString conversion happens on the call
     boundary and non-ASCII text is not lost.

     @se GlvLogTypes.TLogLvl
    }
    procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); virtual; abstract;
  end;

implementation

end.

