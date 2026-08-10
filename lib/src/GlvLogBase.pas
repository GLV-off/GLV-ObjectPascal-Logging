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
  GlvLogTypes;

type
  {
   Basic logging abstraction.

   All subclasses should implement single method - Log
  }
  TLog = class abstract(TInterfacedObject)
  public
    {
     Log text message with specifed log level.

     @se GlvLogTypes.TLogLvl
    }
    procedure Log(const ALvl: TLogLvl; const ATxt: string); virtual; abstract;
  end;

implementation

end.

