unit LogTestUnit;

{$I 'glv_log_test'}

interface

uses
  Glv.Testing.Cross,
  GlvLog;

type
  TDemosTest = class(TCrossTestCase)
  published
    procedure TestDateUtils;
  end;

  TCustomLogTest = class(TCrossTestCase)
  strict private
    FLastLogged: UnicodeString;
    FLastLvl: TLogLvl;
   protected
    procedure SetUp; override;
    procedure TearDown; override;
  public
    procedure FakeLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
  published
    procedure TestHookUp;
  end;

  TLogLvlTest = class(TCrossTestCase)
  published
    procedure TestAsStr;
  end;

implementation

uses
  DateUtils,
  SysUtils;

procedure TDemosTest.TestDateUtils;
var
  D, D1: TDatetime;
  M1, M2: Word;
begin
  D := EncodeDateTime(2026,01,01, 12, 10, 20, 00);
  D1 := IncMinute(D, 1);
  M1 := MinuteOf(D);
  M2 := MinuteOf(D1);
  Assert.AreNotEqual(M1, M2, 'minutes should not be equal!');
  Assert.AreEqual(10, M1, 'm1 - unexpected minute value');
  Assert.AreEqual(11, M2, 'm2 - unexpected minute value');
end;

procedure TCustomLogTest.SetUp;
begin
  FLastLvl := TLogLvl.llDebug;
  FLastLogged:='';
end;

procedure TCustomLogTest.TearDown;
begin
end;

procedure TCustomLogTest.FakeLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
begin
  FLastLvl := ALvl;
  FLastLogged := ATxt;
end;

procedure TCustomLogTest.TestHookUp;
var
  L: TLog;
begin
  L := TCustomLog.Create(Self.FakeLog);
  try
    L.Log(TLogLvl.llDebug, 'test');
    Assert.AreEqual(Ord(FLastLvl), Ord(TLogLvl.llDebug), 'lvl not match');
    Assert.AreEqual(UnicodeString('test'), FLastLogged, 'text not match!');
  finally
    FreeAndNil(L);
  end;
end;

procedure TLogLvlTest.TestAsStr;
begin
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llInfo), 'INFO');
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llDebug), 'DEBUG');
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llError), 'ERROR');
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llWarn), 'WARN');
end;

initialization

CrossRegTest(TDemosTest, 'Unit');
CrossRegTest(TCustomLogTest, 'Unit');
CrossRegTest(TLogLvlTest, 'Unit');

end.

