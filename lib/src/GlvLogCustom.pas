unit GlvLogCustom;

{$I 'glv_log_lib.inc'}

interface

uses
  GlvLogTypes,
  GlvLogBase;

type
  TLogCb = procedure(const ALvl: TLogLvl; const ATxt: UnicodeString) of object;

  TCustomLog = class(TLog)
  strict protected
    FCb: TLogCb;
  public
    constructor Create(const ACb: TLogCb);
    destructor Destroy; override;
    procedure Log(const ALvl: TLogLvl; const ATxt: string); override;
  end;

implementation

constructor TCustomLog.Create(const ACb: TLogCb);
begin
  inherited Create;
  FCb := ACb;
end;

destructor TCustomLog.Destroy;
begin
  FCb := nil;
  inherited Destroy;
end;

procedure TCustomLog.Log(const ALvl: TLogLvl; const ATxt: string);
begin
  if Assigned(FCb) then
    FCb(ALvl, ATxt);
end;

end.
