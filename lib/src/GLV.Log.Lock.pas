{
 Module:       GLV.Log.Lock
 Author:       GLV_off
 Description:  Thread-safety decorator for TLog based logging graphs.
 -             Serializes the single Log call of a wrapped logger with
 -             an outside synchronization primitive.
 History:      2026-10-28: Created

 Limitations:
 - Supported primitives are TCriticalSection and TMutex. TEvent /
   TSimpleEvent are not suitable: they have no Acquire / Release pair
   with mutual exclusion semantics.
 - A bare TSynchroObject is RTL dependent: FPC implements it as a real
   lock, while Delphi declares Acquire / Release as abstract methods.
   Pass a concrete primitive.
 - Do not share one primitive between two TLockLog instances and do not
   log recursively from inside a sink callback: reentrancy depends on
   the RTL implementation of the given primitive.
}
unit GLV.Log.Lock;

{$I 'glv_log_lib.inc'}

interface

uses
  SyncObjs,
  GLV.Log.Lvl,
  GlvLogBase;

type
  {
   Decorator that serializes calls to its inner logger.

   Owns the wrapped logger (FInner). The synchronization object is
   created and owned only when the caller passes nil as ASync.
  }
  TLockLog = class(TLog)
  strict private
    { Wrapped logger, freed by this decorator }
    FInner: TLog;
    { Outside lock guarding FInner.Log }
    FSync: TSynchroObject;
    { True when FSync was created by this decorator }
    FOwnsSync: Boolean;
  public
    {
     Constructor.

     ASync = nil          -> creates and owns TCriticalSection
     ASync <> nil, AOwnsSync = False (default) -> borrows ASync,
                             caller frees it after the decorator
     ASync <> nil, AOwnsSync = True -> takes ownership of ASync
    }
    constructor Create(const AInner: TLog;
      const ASync: TSynchroObject = nil;
      const AOwnsSync: Boolean = False);
    { Frees the inner logger and an owned synchronization object }
    destructor Destroy; override;
    {
     Main logging procedure. Acquires the lock, forwards the message
     to FInner and releases the lock (also on exception).
    }
    procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); override;
  end;

implementation

uses
  SysUtils;

constructor TLockLog.Create(const AInner: TLog;
  const ASync: TSynchroObject; const AOwnsSync: Boolean);
begin
  inherited Create;
  FInner := AInner;
  if Assigned(ASync) then
  begin
    FSync := ASync;
    FOwnsSync := AOwnsSync;
  end
  else
  begin
    FSync := TCriticalSection.Create;
    FOwnsSync := True;
  end;
end;

destructor TLockLog.Destroy;
begin
  if FOwnsSync then
    FreeAndNil(FSync);
  FreeAndNil(FInner);
  inherited Destroy;
end;

procedure TLockLog.Log(const InLvl: TLogLvl; const InTxt: UnicodeString);
begin
  FSync.Acquire;
  try
    FInner.Log(InLvl, InTxt);
  finally
    FSync.Release;
  end;
end;

end.
