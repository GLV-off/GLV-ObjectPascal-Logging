program Demo;

{$I 'demo.inc'}
{$APPTYPE CONSOLE}
{$R *.res}

uses
  DemoApp in '..\..\src\DemoApp.pas';

begin
  DemoApp.Run;
end.
