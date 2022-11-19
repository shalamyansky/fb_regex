(*
    Unit       : fb_regex
    Date       : 2022-11-09
    Compiler   : Delphi XE3
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Register UDR function for fb_regex project
    Company    : BWR
*)
//DDL definition
(*
set term ^;

create or alter package regex
as begin

procedure matches(
    "Text"    varchar(8191) character set UTF8
  , "Pattern" varchar(8191) character set UTF8
)returns(
    "Number"  integer
  , "Groups"  varchar(8191) character set UTF8
);

procedure groups(
    "Groups"  varchar(8191) character set UTF8
)returns(
    "Number"  integer
  , "Start"   integer
  , "Finish"  integer
);

function replace(
    "Text"        varchar(8191) character set UTF8
  , "Pattern"     varchar(8191) character set UTF8
  , "Replacement" varchar(8191) character set UTF8
  , "Amount"      integer
  , "Skip"        integer
)returns          varchar(8191) character set UTF8;

procedure split_words(
    "Text"   varchar(8191) character set UTF8
)returns(
    "Number" integer
  , "Word"   varchar(8191) character set UTF8
);

procedure split(
    "Text"      varchar(8191) character set UTF8
  , "Separator" varchar(8191) character set UTF8
)returns(
    "Number"    integer
  , "Part"      varchar(8191) character set UTF8
);

end^

recreate package body regex
as begin

procedure matches(
    "Text"    varchar(8191) character set UTF8
  , "Pattern" varchar(8191) character set UTF8
)returns(
    "Number"  integer
  , "Groups"  varchar(8191) character set UTF8
)external name
    'fb_regex!matches'
engine
    udr
;

procedure groups(
    "Groups"  varchar(8191) character set UTF8
)returns(
    "Number"  integer
  , "Start"   integer
  , "Finish"  integer
)external name
    'fb_regex!groups'
engine
    udr
;

function replace(
    "Text"        varchar(8191) character set UTF8
  , "Pattern"     varchar(8191) character set UTF8
  , "Replacement" varchar(8191) character set UTF8
  , "Amount"      integer
  , "Skip"        integer
)returns          varchar(8191) character set UTF8
external name
    'fb_regex!replace'
engine
    udr
;

procedure split_words(
    "Text"   varchar(8191) character set UTF8
)returns(
    "Number" integer
  , "Word"   varchar(8191) character set UTF8
)external name
    'fb_regex!split_words'
engine
    udr
;

procedure split(
    "Text"      varchar(8191) character set UTF8
  , "Separator" varchar(8191) character set UTF8
)returns(
    "Number"    integer
  , "Part"      varchar(8191) character set UTF8
)external name
    'fb_regex!split'
engine
    udr
;

end^

set term ;^
*)
unit fbregex_register;

interface

uses
    firebird
;

function firebird_udr_plugin( AStatus:IStatus; AUnloadFlagLocal:BooleanPtr; AUdrPlugin:IUdrPlugin ):BooleanPtr; cdecl;


implementation


uses
    fbregex
  , fbsplit
;

var
    myUnloadFlag    : BOOLEAN;
    theirUnloadFlag : BooleanPtr;

function firebird_udr_plugin( AStatus:IStatus; AUnloadFlagLocal:BooleanPtr; AUdrPlugin:IUdrPlugin ):BooleanPtr; cdecl;
begin
    AUdrPlugin.registerProcedure( AStatus, 'matches',     TMatchesFactory.Create()    );
    AUdrPlugin.registerProcedure( AStatus, 'groups',      TGroupsFactory.Create()     );
    AUdrPlugin.registerFunction(  AStatus, 'replace',     TReplaceFactory.Create()    );
    AUdrPlugin.registerProcedure( AStatus, 'split_words', TSplitWordsFactory.Create() );
    AUdrPlugin.registerProcedure( AStatus, 'split',       TSplitFactory.Create()      );

    theirUnloadFlag := AUnloadFlagLocal;
    Result          := @myUnloadFlag;
end;{ firebird_udr_plugin }

procedure InitalizationProc;
begin
    myUnloadFlag := FALSE;
end;{ InitalizationProc }

procedure FinalizationProc;
begin
    if( ( theirUnloadFlag <> nil ) and ( not myUnloadFlag ) )then begin
        theirUnloadFlag^ := TRUE;
    end;
end;{ FinalizationProc }

initialization
begin
    InitalizationProc;
end;

finalization
begin
    FinalizationProc;
end;

end.
