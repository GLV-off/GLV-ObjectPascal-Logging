{
 Module:       GlvLogCustom
 Author:       GLV_off
 Description:  Implementation of customizable logging object.
 -             Used when developer wich using this library
 -             want add as logging tool something new or else.
 -             Or if he not satisfied with default option's.
 History:      2026-08-10: Created
}
unit GlvLogCustom;

{$I 'glv_log_lib.inc'}

interface

uses
  GlvLogTypes,
  GlvLogBase;

type
  {
   Callback used in TCustomLog for abstracting
   real logging implementation.
  }
  TLogCb = procedure(const ALvl: TLogLvl; const ATxt: UnicodeString) of object;

  {
   Custom log object

   Accept at construction callback implementation.
   Good for cases when you have not enough logging option's
   or want inject some logic in logging with TGroupLog combination
   (File logging + network loging + console logging as example).
  }
  TCustomLog = class(TLog)
  strict protected
    { Active callback as implementation of logging }
    FCb: TLogCb;
  public
    { Constructor }
    constructor Create(const ACb: TLogCb);
    { Destructor }
    destructor Destroy; override;
    {
      Main logging procedure. In this instance, redirect all
      parameters to its encapsulated callback
    }
    procedure Log(const ALvl: TLogLvl; const ATxt: string); override;
  end;

implementation

constructor TCustomLog.Create(const ACb: TLogCb);
{ Constructor }
begin
  inherited Create;
  FCb := ACb;
end;

destructor TCustomLog.Destroy;
{ Destructor }
begin
  FCb := nil;
  inherited Destroy;
end;

procedure TCustomLog.Log(const ALvl: TLogLvl; const ATxt: string);
{ Main logging procedure. In this instance, redirect all
  parameters to its encapsulated callback }
begin
  if Assigned(FCb) then
    FCb(ALvl, UTF8Decode(ATxt));
end;

end.
