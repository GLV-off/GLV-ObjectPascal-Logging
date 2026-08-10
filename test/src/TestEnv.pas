unit TestEnv;

{$I 'glv_log_test.inc'}

interface

type
  TEnv = class sealed
  public
    class function Root: UnicodeString; static;

    class function TestFile: UnicodeString; static;

    class function TestAsyncFile: UnicodeString; static;
  end;

implementation

uses
  SysUtils;

class function TEnv.Root: UnicodeString;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

class function TEnv.TestFile: UnicodeString;
begin
  Result := Root() + 'test.log';
end;

class function TEnv.TestAsyncFile: UnicodeString;
begin
  Result := Root() + 'async.log';
end;

end.

