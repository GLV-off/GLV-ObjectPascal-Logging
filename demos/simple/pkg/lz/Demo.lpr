program Demo;

uses
  GlvLog,
  Glv.Log,
  Glv.Log.ConsoleEngine;

procedure DemoV1;
begin
  Info('hello');
  Warn('world');
  Error('from');
  Debug('library');
end;

procedure DemoV2;
begin
  LogInfo('log info');
  LogError('log error');
  LogWarn('log warn');
  LogDebug('log debug');
end;

begin
  DemoV1;
  DemoV2;

  ReadLn;
end.

