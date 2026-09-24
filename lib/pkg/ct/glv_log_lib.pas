{ This file was automatically created by Typhon IDE. Do not edit!
  This source is only used to compile and install the package.
 }

unit glv_log_lib;

{$warn 5023 off : no warning about unused units}
interface

uses
  GlvLog, GlvLogBase, GlvLogCustom, GlvLogDev, GlvLogFileOps, GlvLogFiles, 
  GlvLogGroup, GlvLogTypes, TyphonPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('glv_log_lib', @Register);
end.
