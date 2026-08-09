unit GlvLogBase;

{$I 'glv_log_lib.inc'}

interface

uses
  GlvLogTypes;

type
  TLog = class abstract(TInterfacedObject)
  public
    procedure Log(const ALvl: TLogLvl; const ATxt: string); virtual; abstract;
  end;

implementation

end.

