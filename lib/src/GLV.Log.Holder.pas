{
 Module:       GLV.Log.Holder
 Author:       GLV_off
 Description:  Runtime container of the active logging graph for the V2
 -             engine plus a stable proxy procedure registered in
 -             TLogEngine. Client code keeps using GLV.Log.LogInfo and
 -             friends and never sees TLog.
 History:      2026-10-28: Created

 Contract:
 - The TLogEngine callback is installed once, on the first non-nil
   assignment, and is never replaced afterwards. The first assignment
   must happen before worker threads start (see the TLogEngineCallback
   race described in doc/v2/design_builder_ru.md).
 - Later assignments are a hot-swap: the previous graph is not freed but
   moved to the retired list and lives until the holder is finalized, so
   a thread already inside OldGraph.Log cannot hit use-after-free.
 - FInst and the retired list always own disjoint sets. Installing a
   graph that was retired earlier takes it back from the retired list
   instead of owning it twice.
 - Inst := nil disables logging: the proxy raises
   ELoggingEngineNotInitialized.
 - Graphs handed to the holder are owned by it; never free them in
   client code.
 - Do not mix with GLV.Log.ConsoleEngine / GLV.Log.SyncFileEngine: those
   install their own callback in initialization.
}
unit GLV.Log.Holder;

{$I 'glv_log_lib.inc'}

interface

uses
  SyncObjs,
  Generics.Collections,
  GLV.Log.Lvl,
  GLV.Log.Engine,
  GlvLogBase;

type
  {
   Container of the active logging graph.

   Inst is the graph used by the engine proxy; the holder owns it and
   every replaced graph until finalization.
  }
  TLogHolder = class sealed
  strict private class var
    { Currently active graph }
    FInst: TLog;
    { Replaced graphs, kept alive for threads still logging into them }
    FRetired: TObjectList<TLog>;
    { Guards FInst / FRetired and the first callback registration }
    FLock: TCriticalSection;
    { True when the engine proxy is already registered }
    FRegistered: Boolean;
    class function GetInst: TLog; static;
    class procedure SetInst(const AValue: TLog); static;
  public
    class constructor Create;
    class destructor Destroy;

    {
     Active logging graph.

     Setter is a hot-swap: the old graph is retired, not freed. The
     first non-nil assignment registers the engine proxy.
    }
    class property Inst: TLog read GetInst write SetInst;
  end;

  {
   Stable engine proxy. Registered once as TLogEngine callback and
   forwards every message to TLogHolder.Inst.
  }
procedure HolderLog(const InLvl: TLogLvl; const InTxt: UnicodeString);

implementation

uses
  SysUtils;

procedure HolderLog(const InLvl: TLogLvl; const InTxt: UnicodeString);
var
  L: TLog;
begin
  L := TLogHolder.Inst;
  if not Assigned(L) then
    raise ELoggingEngineNotInitialized.Create(
      'GLV.Log.Holder: TLogHolder.Inst is not configured');
  L.Log(InLvl, InTxt);
end;

class constructor TLogHolder.Create;
begin
  FInst := nil;
  FRetired := TObjectList<TLog>.Create(True);
  FLock := TCriticalSection.Create;
  FRegistered := False;
end;

class destructor TLogHolder.Destroy;
begin
  { No worker threads are expected at finalization: stop them first. }
  FreeAndNil(FInst);
  FreeAndNil(FRetired);
  FreeAndNil(FLock);
end;

class function TLogHolder.GetInst: TLog;
begin
  Result := FInst;
end;

class procedure TLogHolder.SetInst(const AValue: TLog);
var
  I: Integer;
begin
  FLock.Acquire;
  try
    if AValue = FInst then
      Exit;

    if not FRegistered then
    begin
      TLogEngine.SetCb(@HolderLog);
      FRegistered := True;
    end;

    { A retired graph may be installed again (a reloaded config can
      toggle between two graphs). Take it back into service first, so
      that FInst and FRetired always own disjoint sets and no object is
      freed twice at finalization. }
    if Assigned(AValue) then
    begin
      I := FRetired.IndexOf(AValue);
      if I >= 0 then
      begin
        FRetired.OwnsObjects := False;
        try
          FRetired.Delete(I);
        finally
          FRetired.OwnsObjects := True;
        end;
      end;
    end;

    if Assigned(FInst) then
      FRetired.Add(FInst);
    FInst := AValue;
  finally
    FLock.Release;
  end;
end;

end.
