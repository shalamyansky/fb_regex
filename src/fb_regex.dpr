(*
    Unit       : fb_regex
    Date       : 2022-09-09
    Compiler   : Delphi XE3
    ęCopyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR regular expressions plugin module
    Project    : https://github.com/shalamyansky/fb_regex
    Company    : BWR
*)
library fb_regex;

uses
    fbregex_register
;

{$R *.res}

exports
    firebird_udr_plugin
;

begin
end.
