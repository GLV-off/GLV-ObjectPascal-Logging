unit LogTestUnit;

{$I 'glv_log_test'}

interface

uses
  Glv.Testing.Cross,
  GLV.Log,
  GLV.Log.Engine,
  GLV.Log.Builder,
  GLV.Log.Holder,
  GlvLog,
  SysUtils,
  Classes,
  SyncObjs;

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
    procedure TestUnicodeText;
  end;

  TLogLvlTest = class(TCrossTestCase)
  published
    procedure TestAsStr;
  end;

  { Exception raised by TLogSpy on demand }
  ESinkFailure = class(Exception);

  {
   Synchronization primitive spy.

   Does not block anybody: only records Acquire / Release calls and its
   own destruction, so a test can see how TLockLog uses the lock.
  }
  TLockSpy = class(TSynchroObject)
  public
    class var
      Acquires: Integer;
      Releases: Integer;
      DestroyCount: Integer;
  public
    class procedure Reset;
    procedure Acquire; override;
    procedure Release; override;
    destructor Destroy; override;
  end;

  {
   Sink spy.

   Records every delivered message and can fail on demand. Used to check
   routing, ordering and ownership without any real output.
  }
  TLogSpy = class(TLog)
  public
    class var DestroyCount: Integer;
  strict private
    FCount: Integer;
    FLastLvl: TLogLvl;
    FLastTxt: UnicodeString;
    FRaiseOnLog: Boolean;
  public
    class procedure ResetDestroyCount;
    destructor Destroy; override;
    procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); override;
    property Count: Integer read FCount;
    property LastLvl: TLogLvl read FLastLvl;
    property LastTxt: UnicodeString read FLastTxt;
    property RaiseOnLog: Boolean read FRaiseOnLog write FRaiseOnLog;
  end;

  {
   Sink that appends its tag to a shared sequence.

   Two such sinks in one TGroupLog show the real output order.
  }
  TSeqLog = class(TLog)
  strict private
    FTag: UnicodeString;
  public
    constructor Create(const ATag: UnicodeString);
    procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); override;
  end;

  { Worker that logs through the V2 engine proxy (GLV.Log.LogInfo) }
  TLogSwapWorker = class(TThread)
  strict private
    FCount: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(const ACount: Integer);
  end;

  TLockLogTest = class(TCrossTestCase)
  published
    procedure TestAcquireBeforeLogReleaseAfter;
    procedure TestReleaseOnException;
    procedure TestBorrowedSyncNotFreed;
    procedure TestOwnedSyncFreed;
    procedure TestDefaultSync;
  end;

  TLogBuilderTest = class(TCrossTestCase)
  published
    procedure TestNoSinksRaises;
    procedure TestAddNilRaises;
    procedure TestSingleSinkIsReturned;
    procedure TestTwoSinksMergedInGroup;
    procedure TestOutputOrderFollowsAdd;
    procedure TestBuildTransfersOwnership;
    procedure TestRebuildReturnsNewGraph;
    procedure TestWithLockWrapsWholeGraph;
    procedure TestLockRequestConsumedByBuild;
  end;

  TLogHolderTest = class(TCrossTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInstRoutesMessage;
    procedure TestReassignKeepsOldGraphAlive;
    procedure TestReassignRetiredGraphTwice;
    procedure TestNilInstRaises;
    procedure TestHotSwap;
  end;

implementation

uses
  DateUtils;

const
  { U+4E2D and U+1F600: not representable in single-byte code pages,
    so an implicit UnicodeString -> AnsiString conversion is visible. }
  UnicodeText: UnicodeString = #$4E2D#$1F600;

var
  { Shared call sequence of TSeqLog and TLockSpy }
  GSeq: UnicodeString;

{ TLockSpy }

class procedure TLockSpy.Reset;
begin
  Acquires := 0;
  Releases := 0;
  DestroyCount := 0;
end;

procedure TLockSpy.Acquire;
begin
  Inc(Acquires);
  GSeq := GSeq + 'A';
end;

procedure TLockSpy.Release;
begin
  Inc(Releases);
  GSeq := GSeq + 'R';
end;

destructor TLockSpy.Destroy;
begin
  Inc(DestroyCount);
  inherited Destroy;
end;

{ TLogSpy }

class procedure TLogSpy.ResetDestroyCount;
begin
  DestroyCount := 0;
end;

destructor TLogSpy.Destroy;
begin
  Inc(DestroyCount);
  inherited Destroy;
end;

procedure TLogSpy.Log(const InLvl: TLogLvl; const InTxt: UnicodeString);
begin
  Inc(FCount);
  FLastLvl := InLvl;
  FLastTxt := InTxt;
  if FRaiseOnLog then
    raise ESinkFailure.Create('sink spy: requested failure');
end;

{ TSeqLog }

constructor TSeqLog.Create(const ATag: UnicodeString);
begin
  inherited Create;
  FTag := ATag;
end;

procedure TSeqLog.Log(const InLvl: TLogLvl; const InTxt: UnicodeString);
begin
  GSeq := GSeq + FTag;
end;

{ TLogSwapWorker }

constructor TLogSwapWorker.Create(const ACount: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FCount := ACount;
end;

procedure TLogSwapWorker.Execute;
var
  I: Integer;
begin
  for I := 1 to FCount do
  begin
    if Terminated then
      Exit;
    GLV.Log.LogInfo('hot-swap message');
  end;
end;

{ TDemosTest }

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

{ TCustomLogTest }

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

procedure TCustomLogTest.TestUnicodeText;
var
  L: TLog;
begin
  L := TCustomLog.Create(Self.FakeLog);
  try
    L.Log(TLogLvl.llInfo, UnicodeText);
    Assert.AreEqual(UnicodeText, FLastLogged, 'unicode text corrupted on the way to callback');
  finally
    FreeAndNil(L);
  end;
end;

{ TLogLvlTest }

procedure TLogLvlTest.TestAsStr;
begin
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llInfo), 'INFO');
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llDebug), 'DEBUG');
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llError), 'ERROR');
  Assert.AreEqual(LogLvlAsStr(TLogLvl.llWarn), 'WARN');
end;

{ TLockLogTest }

procedure TLockLogTest.TestAcquireBeforeLogReleaseAfter;
var
  S: TSeqLog;
  Lock: TLockSpy;
  L: TLockLog;
begin
  GSeq := '';
  S := TSeqLog.Create('L');
  Lock := TLockSpy.Create;
  L := TLockLog.Create(S, Lock);
  try
    L.Log(TLogLvl.llInfo, 'ordered message');
    Assert.AreEqual(UnicodeString('ALR'), GSeq,
      'expected Acquire -> callback -> Release order');
  finally
    FreeAndNil(L);
    FreeAndNil(Lock);
  end;
end;

procedure TLockLogTest.TestReleaseOnException;
var
  S: TLogSpy;
  Lock: TLockSpy;
  L: TLockLog;
  Raised: Boolean;
begin
  TLockSpy.Reset;
  S := TLogSpy.Create;
  S.RaiseOnLog := True;
  Lock := TLockSpy.Create;
  L := TLockLog.Create(S, Lock);
  try
    Raised := False;
    try
      L.Log(TLogLvl.llError, 'boom');
    except
      on E: ESinkFailure do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'exception from the sink should propagate');
    Assert.AreEqual(Int64(1), Int64(TLockSpy.Acquires), 'lock was not acquired');
    Assert.AreEqual(Int64(1), Int64(TLockSpy.Releases),
      'lock was not released after the exception');
  finally
    FreeAndNil(L);
    FreeAndNil(Lock);
  end;
end;

procedure TLockLogTest.TestBorrowedSyncNotFreed;
var
  S: TLogSpy;
  Lock: TLockSpy;
  L: TLockLog;
begin
  TLockSpy.Reset;
  S := TLogSpy.Create;
  Lock := TLockSpy.Create;
  L := TLockLog.Create(S, Lock);
  try
    L.Log(TLogLvl.llInfo, 'borrowed lock');
    Assert.AreEqual(Int64(1), Int64(TLockSpy.Acquires), 'borrowed lock was not used');
  finally
    FreeAndNil(L);
  end;
  Assert.AreEqual(Int64(0), Int64(TLockSpy.DestroyCount),
    'borrowed lock must not be freed by TLockLog');
  FreeAndNil(Lock);
  Assert.AreEqual(Int64(1), Int64(TLockSpy.DestroyCount), 'lock spy was not freed by the test');
end;

procedure TLockLogTest.TestOwnedSyncFreed;
var
  S: TLogSpy;
  Lock: TLockSpy;
  L: TLockLog;
begin
  TLockSpy.Reset;
  S := TLogSpy.Create;
  Lock := TLockSpy.Create;
  L := TLockLog.Create(S, Lock, True);
  L.Log(TLogLvl.llInfo, 'owned lock');
  Assert.AreEqual(Int64(1), Int64(S.Count), 'message was not delivered');
  FreeAndNil(L);
  Assert.AreEqual(Int64(1), Int64(TLockSpy.DestroyCount),
    'lock passed with AOwnsSync = True must be freed by TLockLog');
end;

procedure TLockLogTest.TestDefaultSync;
var
  S: TLogSpy;
  L: TLockLog;
begin
  S := TLogSpy.Create;
  L := TLockLog.Create(S);
  try
    L.Log(TLogLvl.llWarn, 'own critical section');
    Assert.AreEqual(Int64(1), Int64(S.Count), 'message was not delivered');
  finally
    FreeAndNil(L);
  end;
end;

{ TLogBuilderTest }

procedure TLogBuilderTest.TestNoSinksRaises;
var
  B: TLogBuilder;
  G: TLog;
  Raised: Boolean;
begin
  B := TLogBuilder.Create;
  try
    G := nil;
    Raised := False;
    try
      G := B.Build;
    except
      on E: ELogBuilderError do
      begin
        Raised := True;
        G := nil;
      end;
    end;
    Assert.IsTrue(Raised, 'empty builder should raise ELogBuilderError');
    Assert.IsNull(G, 'empty builder should not return a graph');
  finally
    FreeAndNil(G);
    FreeAndNil(B);
  end;
end;

procedure TLogBuilderTest.TestAddNilRaises;
var
  B: TLogBuilder;
  Raised: Boolean;
begin
  B := TLogBuilder.Create;
  try
    Raised := False;
    try
      B.Add(nil);
    except
      on E: ELogBuilderError do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'Add(nil) should raise ELogBuilderError');
  finally
    FreeAndNil(B);
  end;
end;

procedure TLogBuilderTest.TestSingleSinkIsReturned;
var
  B: TLogBuilder;
  S: TLogSpy;
  G: TLog;
begin
  B := TLogBuilder.Create;
  S := TLogSpy.Create;
  G := B.Add(S).Build;
  try
    Assert.IsTrue(G = S, 'single sink should be returned as is, without a group');
  finally
    FreeAndNil(B);
    FreeAndNil(G);
  end;
end;

procedure TLogBuilderTest.TestTwoSinksMergedInGroup;
var
  B: TLogBuilder;
  S1, S2: TLogSpy;
  G: TLog;
begin
  B := TLogBuilder.Create;
  S1 := TLogSpy.Create;
  S2 := TLogSpy.Create;
  G := B.Add(S1).Add(S2).Build;
  try
    Assert.IsTrue(G is TGroupLog, 'two sinks should be wrapped in TGroupLog');
    G.Log(TLogLvl.llWarn, 'fan-out');
    Assert.AreEqual(Int64(1), Int64(S1.Count), 'first sink did not receive the message');
    Assert.AreEqual(Int64(1), Int64(S2.Count), 'second sink did not receive the message');
  finally
    FreeAndNil(B);
    FreeAndNil(G);
  end;
end;

procedure TLogBuilderTest.TestOutputOrderFollowsAdd;
var
  B: TLogBuilder;
  G: TLog;
begin
  GSeq := '';
  B := TLogBuilder.Create;
  G := B.Add(TSeqLog.Create('A')).Add(TSeqLog.Create('B')).Build;
  try
    G.Log(TLogLvl.llInfo, 'order');
    Assert.AreEqual(UnicodeString('AB'), GSeq,
      'output order should follow the Add order');
  finally
    FreeAndNil(B);
    FreeAndNil(G);
  end;
end;

procedure TLogBuilderTest.TestBuildTransfersOwnership;
var
  B: TLogBuilder;
  S: TLogSpy;
  G: TLog;
  Before: Integer;
begin
  TLogSpy.ResetDestroyCount;
  Before := TLogSpy.DestroyCount;
  B := TLogBuilder.Create;
  S := TLogSpy.Create;
  G := B.Add(S).Build;
  try
    FreeAndNil(B); { the builder must not free a graph it has handed over }
    Assert.AreEqual(Int64(Before), Int64(TLogSpy.DestroyCount),
      'builder freed the graph after Build');
    G.Log(TLogLvl.llInfo, 'alive after builder destruction');
    Assert.AreEqual(Int64(1), Int64(S.Count),
      'graph is not usable after the builder destruction');
  finally
    FreeAndNil(G);
  end;
  Assert.AreEqual(Int64(Before + 1), Int64(TLogSpy.DestroyCount),
    'single-sink graph should be freed by its new owner');
end;

procedure TLogBuilderTest.TestRebuildReturnsNewGraph;
var
  B: TLogBuilder;
  S1, S2, S3, S4: TLogSpy;
  G1, G2: TLog;
begin
  B := TLogBuilder.Create;
  S1 := TLogSpy.Create;
  S2 := TLogSpy.Create;
  S3 := TLogSpy.Create;
  S4 := TLogSpy.Create;
  G1 := B.Add(S1).Add(S2).Build;
  G2 := B.Add(S3).Add(S4).Build;
  try
    Assert.IsTrue(G1 <> G2, 'Build should return a new graph for a new configuration');
    Assert.IsTrue(G1 is TGroupLog, 'first graph should be a group');
    Assert.IsTrue(G2 is TGroupLog, 'second graph should be a group');
  finally
    FreeAndNil(B);
    FreeAndNil(G2);
    FreeAndNil(G1);
  end;
end;

procedure TLogBuilderTest.TestWithLockWrapsWholeGraph;
var
  B: TLogBuilder;
  S1, S2: TLogSpy;
  Lock: TLockSpy;
  G: TLog;
begin
  TLockSpy.Reset;
  B := TLogBuilder.Create;
  S1 := TLogSpy.Create;
  S2 := TLogSpy.Create;
  Lock := TLockSpy.Create;
  G := B.Add(S1).Add(S2).WithLock(Lock).Build;
  try
    Assert.IsTrue(G is TLockLog, 'WithLock should wrap the whole graph in TLockLog');
    G.Log(TLogLvl.llInfo, 'locked fan-out');
    Assert.AreEqual(Int64(1), Int64(TLockSpy.Acquires),
      'the whole graph should be guarded by one acquisition per message');
    Assert.AreEqual(Int64(1), Int64(TLockSpy.Releases), 'lock was not released');
    Assert.AreEqual(Int64(1), Int64(S1.Count), 'first sink did not receive the message');
    Assert.AreEqual(Int64(1), Int64(S2.Count), 'second sink did not receive the message');
  finally
    FreeAndNil(B);
    FreeAndNil(G);
  end;
  Assert.AreEqual(Int64(0), Int64(TLockSpy.DestroyCount),
    'lock passed to WithLock must not be freed by the graph');
  FreeAndNil(Lock);
end;

procedure TLogBuilderTest.TestLockRequestConsumedByBuild;
var
  B: TLogBuilder;
  S1, S2, S3, S4: TLogSpy;
  Lock: TLockSpy;
  G1, G2: TLog;
begin
  B := TLogBuilder.Create;
  S1 := TLogSpy.Create;
  S2 := TLogSpy.Create;
  S3 := TLogSpy.Create;
  S4 := TLogSpy.Create;
  Lock := TLockSpy.Create;
  G1 := B.Add(S1).Add(S2).WithLock(Lock).Build;
  G2 := B.Add(S3).Add(S4).Build;
  try
    Assert.IsTrue(G1 is TLockLog, 'first graph should be locked');
    Assert.IsFalse(G2 is TLockLog,
      'lock request should be consumed by the previous Build');
  finally
    FreeAndNil(B);
    FreeAndNil(G2);
    FreeAndNil(G1);
    FreeAndNil(Lock);
  end;
end;

{ TLogHolderTest }

procedure TLogHolderTest.SetUp;
begin
  { Isolate the process-wide holder state between tests. Graphs handed
    to the holder are owned by it and are never freed here. }
  TLogHolder.Inst := nil;
  TLogSpy.ResetDestroyCount;
end;

procedure TLogHolderTest.TearDown;
begin
  TLogHolder.Inst := nil;
end;

procedure TLogHolderTest.TestInstRoutesMessage;
var
  S: TLogSpy;
begin
  S := TLogSpy.Create;
  TLogHolder.Inst := S;
  GLV.Log.LogInfo(UnicodeText);
  Assert.AreEqual(Int64(1), Int64(S.Count),
    'message was not delivered through the holder');
  Assert.AreEqual(Int64(Ord(TLogLvl.llInfo)), Int64(Ord(S.LastLvl)),
    'level was not delivered through the holder');
  Assert.AreEqual(UnicodeText, S.LastTxt,
    'unicode text corrupted on the way through the holder');
end;

procedure TLogHolderTest.TestReassignKeepsOldGraphAlive;
var
  S1, S2: TLogSpy;
  Before: Integer;
begin
  TLogSpy.ResetDestroyCount;
  Before := TLogSpy.DestroyCount;
  S1 := TLogSpy.Create;
  S2 := TLogSpy.Create;
  TLogHolder.Inst := S1;
  TLogHolder.Inst := S2;
  Assert.AreEqual(Int64(Before), Int64(TLogSpy.DestroyCount),
    'hot-swap must not free the replaced graph');
  GLV.Log.LogInfo('second graph');
  Assert.AreEqual(Int64(1), Int64(S2.Count), 'new graph did not receive the message');
  Assert.AreEqual(Int64(0), Int64(S1.Count), 'retired graph received the message');
end;

procedure TLogHolderTest.TestReassignRetiredGraphTwice;
var
  S1, S2: TLogSpy;
begin
  S1 := TLogSpy.Create;
  S2 := TLogSpy.Create;
  TLogHolder.Inst := S1;
  TLogHolder.Inst := S2;
  { Re-install a graph that is already retired: ownership must not be
    duplicated (a double free would be visible at holder finalization). }
  TLogHolder.Inst := S1;
  GLV.Log.LogInfo('back to the first graph');
  Assert.AreEqual(Int64(1), Int64(S1.Count), 're-installed graph did not receive the message');
  Assert.AreEqual(Int64(0), Int64(S2.Count), 'retired graph received the message');
end;

procedure TLogHolderTest.TestNilInstRaises;
var
  Raised: Boolean;
begin
  TLogHolder.Inst := nil;
  Raised := False;
  try
    GLV.Log.LogInfo('nobody listens');
  except
    on E: ELoggingEngineNotInitialized do
      Raised := True;
  end;
  Assert.IsTrue(Raised,
    'logging without an installed graph should raise ELoggingEngineNotInitialized');
end;

procedure TLogHolderTest.TestHotSwap;
var
  S1, S2: TLogSpy;
  W: TLogSwapWorker;
  I: Integer;
begin
  S1 := TLogSpy.Create;
  S2 := TLogSpy.Create;
  TLogHolder.Inst := S1;
  W := TLogSwapWorker.Create(200);
  try
    W.Start;
    for I := 1 to 25 do
    begin
      TLogHolder.Inst := S2;
      TLogHolder.Inst := S1;
    end;
    W.WaitFor;
  finally
    FreeAndNil(W);
  end;
  Assert.AreEqual(Int64(200), Int64(S1.Count + S2.Count),
    'every message must reach a live sink during hot-swap');
end;

initialization

CrossRegTest(TDemosTest, 'Unit');
CrossRegTest(TCustomLogTest, 'Unit');
CrossRegTest(TLogLvlTest, 'Unit');
CrossRegTest(TLockLogTest, 'Unit');
CrossRegTest(TLogBuilderTest, 'Unit');
CrossRegTest(TLogHolderTest, 'Unit');

end.
