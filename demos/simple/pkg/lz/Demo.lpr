program Demo;

uses
  GLV.Log,
  GLV.Log.ConsoleEngine;

begin
  LogInfo('log info');
  LogError('log error');
  LogWarn('log warn');
  LogDebug('log debug');

  ReadLn;
end.

