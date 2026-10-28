program BuilderDemo;

{$IFDEF FPC}
{$MODE DELPHI}
{$H+}
{$ENDIF FPC}

uses
  BuilderDemoApp;

begin
  ExitCode := BuilderDemoApp.Run;
end.
