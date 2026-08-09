unit GlvLogTest;

{$I 'glv_log_test'}

interface

uses
  Glv.Testing.Cross,
  GlvLog;

type
  TCustomLogTest = class(TCrossTestCase)
  strict private
    FLastLogged: string;
    FLastLvl: TLogLvl;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  public
    procedure FakeLog(const ALvl: TLogLvl; const ATxt: string);
  published
    procedure TestHookUp;
  end;

implementation

uses
  SysUtils;

procedure TCustomLogTest.SetUp;
begin
  FLastLvl := TLogLvl.llDebug;
  FLastLogged:='';
end;

procedure TCustomLogTest.TearDown;
begin
end;

procedure TCustomLogTest.FakeLog(const ALvl: TLogLvl; const ATxt: string);
begin
  FLastLvl := ALvl;
  FLastLogged := ATxt;
end;

procedure TCustomLogTest.TestHookUp;
var
  L: TLog;
begin
  L := TCustomLog.Create(@TCustomLogTest.FakeLog);
  try
    L.Log(TLogLvl.llDebug, 'test');
    Assert.AreEqual(Ord(FLastLvl), Ord(TLogLvl.llDebug), 'lvl not match');
    Assert.AreEqual('test', FLastLogged, 'text not match!');
  finally
    FreeAndNil(L);
  end;
end;

initialization

CrossRegTest(TCustomLogTest, 'Unit');

end.

