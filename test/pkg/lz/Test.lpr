program Test;

{$I 'glv_log_test.inc'}

uses
  Glv.Testing.App,
  GlvLogTest;

begin
  Run('GLV Log autotests');
{$IFDEF DEBUG}
  ReadLn;
{$ENDIF DEBUG}
end.
