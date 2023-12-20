(*
    Unit       : fbregex_register
    Date       : 2022-11-09
    Compiler   : Delphi XE3, Delphi 12
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Register UDR function for fb_regex project
    Project    : https://github.com/shalamyansky/fb_regex
    Company    : BWR
*)
(*
    References and thanks:

    Denis Simonov. Firebird UDR writing in Pascal.
                   2019, IBSurgeon

*)
//DDL definition
(*
set term ^;

create or alter package regex
as begin

procedure matches(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
)returns(
    number  integer
  , groups  varchar(8191) character set UTF8
);

procedure groups(
    groups varchar(8191) character set UTF8
)returns(
    number integer
  , origin integer
  , finish integer
);

procedure find(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , amount  integer
  , pass    integer
)returns(
    number  integer
  , match   varchar(8191) character set UTF8
);

function find_first(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , pass    integer
)returns    varchar(8191) character set UTF8;

function replace(
    text        varchar(8191) character set UTF8
  , pattern     varchar(8191) character set UTF8
  , replacement varchar(8191) character set UTF8
  , amount      integer
  , pass        integer
)returns        varchar(8191) character set UTF8;

procedure split(
    text      varchar(8191) character set UTF8
  , separator varchar(8191) character set UTF8
)returns(
    number    integer
  , part      varchar(8191) character set UTF8
);

procedure split_words(
    text   varchar(8191) character set UTF8
)returns(
    number integer
  , word   varchar(8191) character set UTF8
);

end^

recreate package body regex
as
begin

procedure matches(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
)returns(
    number  integer
  , groups  varchar(8191) character set UTF8
)external name
    'fb_regex!matches'
engine
    udr
;

procedure groups(
    groups varchar(8191) character set UTF8
)returns(
    number integer
  , origin integer
  , finish integer
)external name
    'fb_regex!groups'
engine
    udr
;

procedure find(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , amount  integer
  , pass    integer
)returns(
    number  integer
  , match   varchar(8191) character set UTF8
)external name
    'fb_regex!find'
engine
    udr
;

function find_first(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , pass    integer
)returns    varchar(8191) character set UTF8
external name
    'fb_regex!find_first'
engine
    udr
;

function replace(
    text        varchar(8191) character set UTF8
  , pattern     varchar(8191) character set UTF8
  , replacement varchar(8191) character set UTF8
  , amount      integer
  , pass        integer
)returns        varchar(8191) character set UTF8
external name
    'fb_regex!replace'
engine
    udr
;

procedure split(
    text      varchar(8191) character set UTF8
  , separator varchar(8191) character set UTF8
)returns(
    number    integer
  , part      varchar(8191) character set UTF8
)external name
    'fb_regex!split'
engine
    udr
;

procedure split_words(
    text   varchar(8191) character set UTF8
)returns(
    number integer
  , word   varchar(8191) character set UTF8
)external name
    'fb_regex!split_words'
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
    Windows
  , fbregex
  , fbfind
  , fbsplit
;

var
    myUnloadFlag    : BOOLEAN = FALSE;
    theirUnloadFlag : BooleanPtr;

function firebird_udr_plugin( AStatus:IStatus; AUnloadFlagLocal:BooleanPtr; AUdrPlugin:IUdrPlugin ):BooleanPtr; cdecl;
begin
    AUdrPlugin.registerProcedure( AStatus, 'matches',     fbregex.TMatchesFactory.Create()    );
    AUdrPlugin.registerProcedure( AStatus, 'groups',      fbregex.TGroupsFactory.Create()     );
    AUdrPlugin.registerProcedure( AStatus, 'find',        fbfind.TFindFactory.Create()        );
    AUdrPlugin.registerFunction(  AStatus, 'find_first',  fbfind.TFindFirstFactory.Create()   );
    AUdrPlugin.registerFunction(  AStatus, 'replace',     fbfind.TReplaceFactory.Create()     );
    AUdrPlugin.registerProcedure( AStatus, 'split_words', fbsplit.TSplitWordsFactory.Create() );
    AUdrPlugin.registerProcedure( AStatus, 'split',       fbsplit.TSplitFactory.Create()      );

    theirUnloadFlag := AUnloadFlagLocal;
    Result          := @myUnloadFlag;
end;{ firebird_udr_plugin }

procedure InitalizationProc;
begin
    IsMultiThread := TRUE;
    myUnloadFlag  := FALSE;
end;{ InitalizationProc }

procedure FinalizationProc;
begin
    try
        if(
              ( not myUnloadFlag )
          and ( theirUnloadFlag <> nil )
          and ( not IsBadWritePtr( theirUnloadFlag, SizeOf( theirUnloadFlag^ ) ) )
        )then begin
            theirUnloadFlag^ := TRUE;
        end;
    except
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
