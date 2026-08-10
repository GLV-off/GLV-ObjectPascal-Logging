{
 Module:       GlvLogGroup
 Author:       GLV_off
 Description:  Implementation of TGroupLog utility object
 -             for grouping loggers as single instance
 -             with unified object interface.
 History:      2026-08-10: Created
}
unit GlvLogGroup;

{$I 'glv_log_lib.inc'}

interface

uses
  Generics.Collections,
  GlvLogTypes,
  GlvLogBase;

type
  {
   List of TLog objects. Used in TGroupLog class
   as main collection type.
  }
  TGroupLogList = TObjectList<TLog>;

  {
   Group Log

   Unifies many concreate instanses of TLog inherited
   objects and redirect Log method call to its children's
  }
  TGroupLog = class(TLog)
  strict private
    {
     list of log objects. Will be
     deleted after list destruction.
     This group owning objects.
    }
    FItems: TGroupLogList;
  public
    {
      Constructor. Accepts array of references to
      Logging object's.
    }
    constructor Create(const AItems: array of TLog);

    {
      Destructor. Clear memory for allocated
      list and objects
    }
    destructor Destroy; override;

    {
      Main logging procedure. Passing log level and message.

      In this class it will redirect level and message to
      its nested childrens who place will be in FItems
      container.
    }
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
  FItems.TrimExcess();
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
    if Assigned(FItems[I]) then
      FItems[I].Log(Alvl, ATxt);
end;

end.
