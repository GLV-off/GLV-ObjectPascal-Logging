unit GlvLogGroup;

{$I 'glv_log_lib.inc'}

interface

uses
  Generics.Collections,
  GlvLogTypes,
  GlvLogBase;

type
  TGroupLogList = TObjectList<TLog>;

  TGroupLog = class(TLog)
  strict private
    FItems: TGroupLogList;
  public
    constructor Create(const AItems: array of TLog);
    destructor Destroy; override;
    procedure Log(const ALvl: TLogLvl; const ATxt: string); override;
  end;

implementation

uses
  SysUtils;

constructor TGroupLog.Create(const AItems: array of TLog);
begin
  inherited Create;
  FItems := TGroupLogList.Create(True);
  FItems.AddRange(AItems);
end;

destructor TGroupLog.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TGroupLog.Log(const ALvl: TLogLvl; const ATxt: string);
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    FItems[I].Log(Alvl, ATxt);
  end;
end;

end.
