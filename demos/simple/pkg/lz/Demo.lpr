program Demo;

uses
  GlvLog,
  GLV.Log,
  GLV.Log.ConsoleEngine;

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

