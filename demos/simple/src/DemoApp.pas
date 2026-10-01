unit DemoApp;

{$I 'demo.inc'}

interface

procedure Run;

implementation

uses
  SysUtils;

procedure RunImpl; forward;

procedure Run;
begin
  try
    RunImpl;
  except
    on E: Exception do
      WriteLn(E.Classname, '', E.Message);
    end;
  end;
end;

procedure RunImpl;
begin
   WriteLn('RunImpl');
end;

end.
