program TestInt;

{$I 'glv_log_test.inc'}

uses
  Glv.Testing.App,
  TestEnv,
  TestFileUtils,
  TestReport,
  LogTestInt;

begin
  Run('GLV Integration automatic tests');
{$IFDEF DEBUG}
  ReadLn;
{$ENDIF DEBUG}
end.
