{
 Module:       GLV.Log.Engine
 Author:       GLV_off
 Description:
 History:      2026-10-28: Created
}
unit GLV.Log.Engine;

{$I 'glv_log_lib.inc'}

interface

uses
  SysUtils,
  GLV.Log.Lvl;

type
  { }
  ELoggingEngineNotInitialized = class(Exception)
  end;

  TLogEngineCallback = record
  public type
    TProc = procedure(const InLvl: TLogLvl; const InTxt: UnicodeString);
    TMeth = procedure(const InLvl: TLogLvl; const InTxt: UnicodeString) of object;
    TKind = (lecNil, leckMeth, leckProc);
  public
    constructor Create(const InMeth: TMeth); overload;
    constructor Create(const InProc: TProc); overload;
    procedure Call(const InLvl: TLogLvl; const InTxt: UnicodeString);
    procedure Reset;
    case Kind: TKind of
      lecNil: (Null: Pointer);
      leckMeth: (Meth: TMeth);
      leckProc: (Proc: TProc);
  end;

  TLogEngine = class sealed(TInterfacedObject)
  strict private class var
    FCb: TLogEngineCallback;
  public
    class constructor Create;
    class destructor Destroy;
    class procedure Call(const InLvl: TLogLvl; const InTxt: UnicodeString); static;
    class procedure SetCb(const InMeth: TLogEngineCallback.TMeth); overload;
    class procedure SetCb(const InProc: TLogEngineCallback.TProc); overload;
  end;

implementation

procedure LogInfo(const InTxt: UnicodeString);
begin
  TLogEngine.Call(TLogLvl.llInfo, InTxt);
end;

constructor TLogEngineCallback.Create(const InMeth: TMeth);
begin
  Self.Kind := TKind.leckMeth;
  Self.Meth := InMeth;
end;

constructor TLogEngineCallback.Create(const InProc: TProc);
begin
  Self.Kind := TKind.leckProc;
  Self.Proc := InProc;
end;

procedure TLogEngineCallback.Call(const InLvl: TLogLvl; const InTxt: UnicodeString);
begin
  case Self.Kind of
    leckMeth:
      if Assigned(Self.Meth) then
        Self.Meth(InLvl, InTxt);
    leckProc:
      if Assigned(Self.Proc) then
        Self.Proc(InLvl, InTxt);
    lecNil:
      begin
        { todo: raise Exception? }
        raise ELoggingEngineNotInitialized.Create('Not initialized engine!');
      end;
  end;
end;

procedure TLogEngineCallback.Reset;
begin
  Self.Kind := TKind.lecNil;
  Self.Null := nil;
end;

class constructor TLogEngine.Create;
begin
  FCb.Reset;
end;

class destructor TLogEngine.Destroy;
begin
  FCb.Reset;
end;

class procedure TLogEngine.Call(const InLvl: TLogLvl; const InTxt: UnicodeString);
begin
  FCb.Call(InLvl, InTxt);
end;

class procedure TLogEngine.SetCb(const InMeth: TLogEngineCallback.TMeth);
begin
  FCb := TLogEngineCallback.Create(InMeth);
end;

class procedure TLogEngine.SetCb(const InProc: TLogEngineCallback.TProc);
begin
  FCb := TLogEngineCallback.Create(InProc);
end;

end.
