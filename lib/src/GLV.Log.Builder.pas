{
 Module:       GLV.Log.Builder
 Author:       GLV_off
 Description:  Fluent builder that assembles a logging graph from
 -             ready-made TLog implementations (console, sync file,
 -             async file, arbitrary sinks) and optionally wraps the
 -             whole graph in a locking decorator.
 History:      2026-10-28: Created

 Ownership:
 - Sinks stay owned by the builder until Build is called.
 - Build transfers ownership: TGroupLog owns the sinks (N > 1), a single
   sink is returned as is and must be freed by the caller.
 - The builder is not thread-safe: configure it on startup.
 - A lock passed to WithLock is borrowed and never freed by the builder.
}
unit GLV.Log.Builder;

{$I 'glv_log_lib.inc'}

interface

uses
  SysUtils,
  Generics.Collections,
  SyncObjs,
  GLV.Log.Lvl,
  GlvLogBase,
  GlvLogCustom,
  GlvLogGroup,
  GlvLogFiles,
  GLV.Log.ConsoleSink,
  GLV.Log.Lock;

type
  { Raised when the builder configuration is not usable }
  ELogBuilderError = class(Exception);

  {
   Fluent builder of a logging graph.

   Order of Add* calls defines the output order of a TGroupLog.
   Build consumes the configuration: sinks are moved into the graph,
   the builder is cleared and can be reused.
  }
  TLogBuilder = class
  strict private
    { Sinks collected for the next Build. Owns them until then }
    FSinks: TObjectList<TLog>;
    { Borrowed lock for WithLock, consumed by the next Build }
    FLock: TSynchroObject;
    { True when the next Build should wrap the graph in TLockLog }
    FLockRequested: Boolean;
    { Move sinks from the builder to the caller without freeing them }
    procedure TakeSinks(out AItems: TArray<TLog>);
  public
    constructor Create;
    destructor Destroy; override;

    { Append an already created sink. The builder takes ownership }
    function Add(const ASink: TLog): TLogBuilder;
    { Append a console sink (TCustomLog + TConsole.ConsoleLog) }
    function Console: TLogBuilder;
    { Append a synchronous file logger with the default clock }
    function SyncFile(const AFileName: UnicodeString): TLogBuilder; overload;
    { Append a synchronous file logger with an injected clock }
    function SyncFile(const AFileName: UnicodeString;
      const ADateTimeFunc: TDateTimeFunc): TLogBuilder; overload;
    { Append an asynchronous file logger }
    function AsyncFile(const AFileName: UnicodeString): TLogBuilder;
    {
     Wrap the whole graph in a TLockLog on the next Build.

     ALock = nil -> TLockLog creates and owns a TCriticalSection
     ALock <> nil -> borrowed, the builder and TLockLog do not free it
    }
    function WithLock(const ALock: TSynchroObject = nil): TLogBuilder;

    {
     Consume the configuration and return the logging graph.

     0 sinks -> ELogBuilderError
     1 sink  -> the sink itself (ownership goes to the caller)
     N sinks -> TGroupLog (owns the sinks)
     WithLock -> the graph above, wrapped in TLockLog
    }
    function Build: TLog;
  end;

implementation

constructor TLogBuilder.Create;
begin
  inherited Create;
  FSinks := TObjectList<TLog>.Create(True);
end;

destructor TLogBuilder.Destroy;
begin
  FreeAndNil(FSinks);
  inherited Destroy;
end;

function TLogBuilder.Add(const ASink: TLog): TLogBuilder;
begin
  if not Assigned(ASink) then
    raise ELogBuilderError.Create('TLogBuilder: sink should not be nil');
  FSinks.Add(ASink);
  Result := Self;
end;

function TLogBuilder.Console: TLogBuilder;
begin
  Result := Add(TCustomLog.Create(TConsole.ConsoleLog));
end;

function TLogBuilder.SyncFile(const AFileName: UnicodeString): TLogBuilder;
begin
  Result := Add(TPrimitiveFileLog.Create(AFileName));
end;

function TLogBuilder.SyncFile(const AFileName: UnicodeString;
  const ADateTimeFunc: TDateTimeFunc): TLogBuilder;
begin
  Result := Add(TPrimitiveFileLog.Create(AFileName, ADateTimeFunc));
end;

function TLogBuilder.AsyncFile(const AFileName: UnicodeString): TLogBuilder;
begin
  Result := Add(TAsyncFileLog.Create(AFileName));
end;

function TLogBuilder.WithLock(const ALock: TSynchroObject): TLogBuilder;
begin
  FLock := ALock;
  FLockRequested := True;
  Result := Self;
end;

procedure TLogBuilder.TakeSinks(out AItems: TArray<TLog>);
begin
  AItems := FSinks.ToArray;
  { Detach objects from the owning list before clearing it: they are
    handed over to the graph, not destroyed by the builder. }
  FSinks.OwnsObjects := False;
  FSinks.Clear;
  FSinks.OwnsObjects := True;
end;

function TLogBuilder.Build: TLog;
var
  Items: TArray<TLog>;
begin
  if FSinks.Count = 0 then
    raise ELogBuilderError.Create('TLogBuilder: no sinks configured');

  TakeSinks(Items);
  if Length(Items) = 1 then
    Result := Items[0]
  else
    Result := TGroupLog.Create(Items);

  { The lock request belongs to the consumed configuration too, so the
    next Build does not wrap a fresh graph with a stale lock. }
  if FLockRequested then
    Result := TLockLog.Create(Result, FLock);
  FLockRequested := False;
  FLock := nil;
end;

end.
