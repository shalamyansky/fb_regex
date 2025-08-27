(*
    Unit       : fb_regex
    Date       : 2022-09-09
    Compiler   : Delphi XE3, Delphi 12
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR regular expressions plugin module
    Project    : https://github.com/shalamyansky/fb_regex
    Company    : BWR
*)

{$DEFINE NO_FBCLIENT}
{Define NO_FBCLIENT in your .dproj file to take effect on firebird.pas}

(* Changes:
 2025-08-27 ver. 3.0.0.0
 - Extended PCRE2 conditional replacement syntax added;
 2025-01-29 ver. 2.1.4.0
 - Blobs are created as stream and temporary ones;
*)

library fb_regex;

uses
  {$IFDEF FastMM}
  {$DEFINE ClearLogFileOnStartup}
  {$DEFINE EnableMemoryLeakReporting}
  FastMM5,
  {$ENDIF }
  fbregex_register;

{$R *.res}

exports
    firebird_udr_plugin
;

begin
end.
