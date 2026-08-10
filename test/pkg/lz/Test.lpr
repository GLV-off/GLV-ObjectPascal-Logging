program Test;

{$I 'glv_log_test.inc'}

uses
  Glv.Testing.App,
  LogTestUnit;

begin
  Run('GLV Log unit autotests');
{$IFDEF DEBUG}
  ReadLn;
{$ENDIF DEBUG}
end.
