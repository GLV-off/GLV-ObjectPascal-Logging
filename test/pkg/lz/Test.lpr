program Test;

{$I 'glv_log_test.inc'}

uses
  Glv.Testing.App,
  TestEnv,
  TestFileUtils,
  LogTestUnit;

begin
  Run('GLV Log unit autotests');
{$IFDEF DEBUG}
  ReadLn;
{$ENDIF DEBUG}
end.
