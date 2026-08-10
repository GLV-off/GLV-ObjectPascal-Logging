unit LogTestInt;

{$I 'glv_log_test.inc'}

interface

uses
  Glv.Testing.Cross,
  TestFileUtils;

type
  TFileLogTest = class(TCrossTestCase)
  strict private
    FFilepath: TFilepath;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPrimitiveFileLog;
  end;

  TAsyncFileLogTest = class(TCrossTestCase)
  strict private
    FFilepath: TFilepath;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAsyncLog;
  end;

function StaticDateTime: TDatetime;

implementation

uses
  SysUtils,
  DateUtils,
  Classes,
  GlvLog,
  TestEnv;

function StaticDateTime: TDatetime;
begin
  Result := EncodeDateTime(2026, 08, 09, 12, 30, 00, 00);
end;

procedure TFileLogTest.SetUp;
begin
  FFilepath := TEnv.TestFile;
end;

procedure TFileLogTest.TearDown;
begin
  FFilepath := '';
end;

procedure TFileLogTest.TestPrimitiveFileLog;
var
  L: TPrimitiveFileLog;
  Lines: TLines;
  Line: TLine;
begin
  L := TPrimitiveFileLog.Create(FFilepath, @StaticDateTime);
  Lines := [];
  Assert.IsFalse(FileExists(FFilepath), 'Test file should not exists!');
  try
    L.Log(TLogLvl.llDebug, 'debug text test write');
    L.Log(TLogLvl.llInfo, 'info text');
    L.Log(TLogLvl.llError, 'error text');
    L.Log(TLogLvl.llWarn, 'warn text');

    Assert.IsTrue(FileExists(FFilepath), 'Test file should exists!');

    Lines := TstReadLines(FFilepath);
    Assert.AreEqual(NativeInt(4), Length(Lines), 'unexpected readed lines count');

    Line := Lines[0];
    Assert.AreEqual('2026-08-09 12:30:00 [DEBUG] debug text test write', Line, 'line[0] written in log not match!');
    Line := Lines[1];
    Assert.AreEqual('2026-08-09 12:30:00 [INFO] info text', Line, 'line[1] written in log not match!');
    Line := Lines[2];
    Assert.AreEqual('2026-08-09 12:30:00 [ERROR] error text', Line, 'line[2] written in log not match!');
    Line := Lines[3];
    Assert.AreEqual('2026-08-09 12:30:00 [WARN] warn text', Line, 'line[2] written in log not match!');
  finally
    SetLength(Lines, 0);
    FreeAndNil(L);
    TstDeleteFile(FFilepath);
  end;
end;

procedure TAsyncFileLogTest.SetUp;
begin
  FFilepath := TEnv.TestAsyncFile;
end;

procedure TAsyncFileLogTest.TearDown;
begin
  FFilepath := '';
end;

procedure TAsyncFileLogTest.TestAsyncLog;
var
  L: TAsyncFileLog;
  Lines: TLines;
  Line: TLine;
begin
  L := TAsyncFileLog.Create(FFilepath);
  Lines := [];

  Assert.IsFalse(FileExists(FFilepath), 'Test file should not exists!');

  try
    L.Log(TLogLvl.llDebug, 'debug text test write');
    L.Log(TLogLvl.llInfo, 'info text');
    L.Log(TLogLvl.llError, 'error text');
    L.Log(TLogLvl.llWarn, 'warn text');

    // todo: glv: Придумать альтернативу задержке времени.
    Sleep(500);
    Assert.IsTrue(FileExists(FFilepath), 'Test file should exists!');

    Lines := TstReadLines(FFilepath);
    Assert.AreEqual(NativeInt(4), Length(Lines), 'unexpected readed lines count');

    Line := Lines[0];
    Assert.AreEqual('[DEBUG]: debug text test write', Line, 'line[0] written in log not match!');
    Line := Lines[1];
    Assert.AreEqual('[INFO]: info text', Line, 'line[1] written in log not match!');
    Line := Lines[2];
    Assert.AreEqual('[ERROR]: error text', Line, 'line[2] written in log not match!');
    Line := Lines[3];
    Assert.AreEqual('[WARN]: warn text', Line, 'line[2] written in log not match!');
  finally
    SetLength(Lines, 0);
    FreeAndNil(L);
    TstDeleteFile(FFilepath);
  end;
end;

initialization

CrossRegTest(TFileLogTest, 'Int');
CrossRegTest(TAsyncFileLogTest, 'Int');

end.
