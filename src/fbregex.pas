(*
    Unit       : fbregex
    Date       : 2022-09-09
    Compiler   : Delphi XE3
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR regular expressions support functions
    Project    : https://github.com/shalamyansky/fb_regex
    Company    : BWR
*)

//DDL definition
(*
set term ^;

create or alter procedure matches(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
)returns(
    number  integer
  , groups  varchar(8191) character set UTF8
)external name
    'fb_regex!matches'
engine
    udr
^

create or alter procedure groups(
    groups varchar(8191) character set UTF8
)returns(
    number integer
  , origin integer
  , finish integer
)external name
    'fb_regex!groups'
engine
    udr
^

set term ;^
*)

unit fbregex;

interface

uses
    SysUtils
  , RegularExpressions
  , firebird    // https://github.com/shalamyansky/fb_common
  , fbudr       // https://github.com/shalamyansky/fb_common
;


type

{ match }

TMatchesFactory = class( TBwrProcedureFactory )
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure; override;
end;{ TMatchesFactory }

TMatchesProcedure = class( TBwrSelectiveProcedure )
  const
    INPUT_FIELD_TEXT    = 0;
    INPUT_FIELD_PATTERN = 1;
    OUTPUT_FIELD_NUMBER = 0;
    OUTPUT_FIELD_GROUPS = 1;
  public
    function open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet; override;
end;{ TMatchesProcedure }

TMatchesResultSet = class( TBwrResultSet )
  private
    fMatch  : TMatch;
    fNumber : LONGINT;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TMatchesResultSet }

{ groups }

TGroupsFactory = class( TBwrProcedureFactory )
  public
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure; override;
end;{ TGroupsFactory }

TGroupsProcedure = class( TBwrSelectiveProcedure )
  const
    INPUT_FIELD_GROUPS  = 0;
    OUTPUT_FIELD_NUMBER = 0;
    OUTPUT_FIELD_START  = 1;
    OUTPUT_FIELD_FINISH = 2;
  public
    function open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet; override;
end;{ TGroupsProcedure }

TGroupsResultSet = class( TBwrResultSet )
  private
    fGroups     : UnicodeString;
    fGroupsNull : WORDBOOL;
    fPos        : LONGINT;
    fNumber     : LONGINT;
    function GetNextGroup( out Start:LONGINT; out Finish:LONGINT ):BOOLEAN;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TGroupsResultSet }


implementation


const
    chrColumn     : UnicodeString = ':';
    chrSemicolumn : UnicodeString = ';';

{ TMatchesFactory }

function TMatchesFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TMatchesProcedure.create( AMetadata );
end;{ TMatchesFactory.newItem }

{ TMatchesProcedure }

function TMatchesProcedure.open( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER ):IExternalResultSet;
begin
    inherited open( AStatus, AContext, aInMsg, aOutMsg );
    Result := TMatchesResultSet.create( Self, AStatus, AContext, AInMsg, AOutMsg );
end;{ TMatchesProcedure.open }

{ TMatchesResultSet }

function JoinGroup( Start, Finish : LONGINT ):UnicodeString;
begin
    Result := IntToStr( Start ) + chrColumn + IntToStr( Finish );
end;{ JoinGroup }

function CollateGroups( Match:TMatch ):UnicodeString;
var
    I : LONGINT;
    Group : TGroup;
    Grp   : UnicodeString;
begin
    Result := '';
    if( Match.Success )then begin
        for I := 0 to Match.Groups.Count - 1 do begin
            Group := Match.Groups.Item[ I ];
            Grp   := JoinGroup( Group.Index, Group.Index + Group.Length );
            if( Length( Result ) > 0 )then begin
                Result := Result + chrSemicolumn;
            end;
            Result := Result + Grp;
        end;
    end;
end;{ CollateGroups }

constructor TMatchesResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER );
var
    Text,     Pattern     : UnicodeString;
    TextNull, PatternNull : WORDBOOL;
    TextOk,   PatternOk   : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus, AContext, AInMsg, AOutMsg );

    TextOk    := RoutineContext.ReadInputString( AStatus, TMatchesProcedure.INPUT_FIELD_TEXT,    Text,    TextNull    );
    PatternOk := RoutineContext.ReadInputString( AStatus, TMatchesProcedure.INPUT_FIELD_PATTERN, Pattern, PatternNull );

    fMatch  := TRegEx.Create( Pattern, [ roCompiled ] ).Match( Text );
    fNumber := 0;
end;{ TMatchesResultSet.Create }

function TMatchesResultSet.fetch( AStatus:IStatus ):BOOLEAN;
var
    NumberNull : WORDBOOL;
    NumberOk   : BOOLEAN;
    Groups     : UnicodeString;
    GroupsNull : WORDBOOL;
    GroupsOk   : BOOLEAN;
begin
    Result := fMatch.Success;
    if( Result )then begin
        Inc( fNumber );
        NumberNull := FALSE;
        Groups     := CollateGroups( fMatch );
        GroupsNull := FALSE;

        fMatch := fMatch.NextMatch;
    end else begin
        fNumber    := 0;
        NumberNull := TRUE;
        Groups     := '';
        GroupsNull := TRUE;
    end;
    NumberOk := RoutineContext.WriteOutputLongint( AStatus, TMatchesProcedure.OUTPUT_FIELD_NUMBER, fNumber, NumberNull );
    GroupsOk := RoutineContext.WriteOutputString(  AStatus, TMatchesProcedure.OUTPUT_FIELD_GROUPS, Groups,  GroupsNull );
end;{ TMatchesResultSet.fetch }

{ Groups }

{ TGroupsFactory }

function TGroupsFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TGroupsProcedure.create( AMetadata );
end;{ TGroupsFactory.newItem }

{ TGroupsProcedure }

function TGroupsProcedure.open( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER ):IExternalResultSet;
begin
    inherited open( AStatus, AContext, aInMsg, aOutMsg );
    Result := TGroupsResultSet.create( self, AStatus, AContext, AInMsg, AOutMsg );
end;{ TGroupsProcedure.open }

{ TGroupsResultSet }

constructor TGroupsResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER );
var
    GroupsOk : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus, AContext, AInMsg, AOutMsg );

    GroupsOk := RoutineContext.ReadInputString( AStatus, TGroupsProcedure.INPUT_FIELD_GROUPS, fGroups, fGroupsNull );
    fGroups  := Trim( fGroups );

    fPos := -1;
    if( ( not fGroupsNull ) and ( Length( fGroups ) > 0 ) )then begin
        fPos := 1;
    end;
    fNumber := -1;
end;{ TGroupsResultSet.Create }

function TGroupsResultSet.GetNextGroup( out Start:LONGINT; out Finish:LONGINT ):BOOLEAN;
var
    pClmn, pSemi : LONGINT;
begin
    Result := FALSE;
    Start  := -1;
    Finish := -1;
    if( ( 0 < fPos ) and ( fPos <= Length( fGroups ) ) )then begin
        pClmn  := Pos( chrColumn, fGroups, fPos );
        if( ( pClmn > fPos ) and ( pClmn < Length( fGroups ) ) )then begin
            Start := StrToIntDef( Copy( fGroups, fPos, pClmn - fPos ), -1  );
            fPos  := pClmn + 1;
            if( Start > -1 )then begin
                pSemi  := Pos( chrSemicolumn, fGroups, fPos );
                if( pSemi > fPos )then begin
                    Finish := StrToIntDef( Copy( fGroups, fPos, pSemi - fPos ), -1  );
                    if( Finish > -1 )then begin
                        fPos   := pSemi + 1;
                        Result := TRUE;
                    end;
                end else begin
                    Finish := StrToIntDef( Copy( fGroups, fPos, Length( fGroups ) - fPos + 1 ), -1  );
                    if( Finish > -1 )then begin
                        fPos   := 0;
                        Result := TRUE;
                    end;
                end;
            end;
        end;
    end;
end;{ TGroupsResultSet.GetNextGroup }

function TGroupsResultSet.fetch( AStatus:IStatus ):BOOLEAN;
var
    Start,     Finish     : LONGINT;
    StartNull, FinishNull, NumberNull : WORDBOOL;
    StartOk,   FinishOk ,  NumberOk   : BOOLEAN;
begin
    Result := GetNextGroup( Start, Finish );
    if( Result )then begin
        Inc( fNumber );
    end else begin
        fNumber := -1;
    end;
    NumberNull := not Result;
    StartNull  := not Result;
    FinishNull := not Result;

    NumberOk := RoutineContext.WriteOutputLongint( AStatus, TGroupsProcedure.OUTPUT_FIELD_NUMBER, fNumber, NumberNull );
    StartOk  := RoutineContext.WriteOutputLongint( AStatus, TGroupsProcedure.OUTPUT_FIELD_START,  Start,   StartNull  );
    FinishOk := RoutineContext.WriteOutputLongint( AStatus, TGroupsProcedure.OUTPUT_FIELD_FINISH, Finish,  FinishNull );
end;{ TGroupsResultSet.fetch }

end.
