program Demo;
uses
  GlvLog,
  GlvLogContract,
  GlvLogConsole;
begin
  LogInfo('log info');
  LogError('log info');
  LogWarn('log info');
  LogDebug('log info');

  Info('hello');
  Warn('world');
  Error('from');
  Debug('library');

  ReadLn;
end.

