(*
    Unit       : fbregex
    Date       : 2022-09-09
    Compiler   : Delphi XE3
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR regular expressions support functions
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

end^

set term ;^
*)

unit fbregex;

interface

uses
    SysUtils
  , firebird
  , fbudr
  , RegularExpressions
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
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus ); override;
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
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus ); override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TGroupsResultSet }

{ replace }

TReplaceFactory = class( TBwrFunctionFactory )
  public
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction; override;
end;{ TReplaceFactory }

TReplaceFunction = class( TBwrFunction )
  const
    INPUT_FIELD_TEXT        = 0;
    INPUT_FIELD_PATTERN     = 1;
    INPUT_FIELD_REPLACEMENT = 2;
    INPUT_FIELD_AMOUNT      = 3;
    INPUT_FIELD_SKIP        = 4;
    OUTPUT_FIELD_RESULT     = 0;
  public
    procedure execute( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
end;{ TReplaceFunction }

function Replace( Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;

function firebird_udr_plugin( AStatus:IStatus; AUnloadFlagLocal:BooleanPtr; AUdrPlugin:IUdrPlugin ):BooleanPtr; cdecl;


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
    Result := TMatchesResultSet.create( Self, AStatus );
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

constructor TMatchesResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus );
var
    Text,     Pattern     : UnicodeString;
    TextNull, PatternNull : WORDBOOL;
    TextOk,   PatternOk   : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus );

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
    Result := TGroupsResultSet.create( self, AStatus );
end;{ TGroupsProcedure.open }

{ TGroupsResultSet }

constructor TGroupsResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus );
var
    GroupsOk : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus );

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

{ TReplaceFactory }

function TReplaceFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction;
begin
    Result := TReplaceFunction.create( AMetadata );
end;{ TReplaceFactory.newItem }

{ TReplaceFunction }

procedure TReplaceFunction.execute( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER );
var
    Text, Pattern, Replacement, Result : UnicodeString;
    Amount, Skip : LONGINT;
    TextNull, PatternNull, ReplacementNull, AmountNull, SkipNull, ResultNull : WORDBOOL;
    TextOk,   PatternOk,   ReplacementOk,   AmountOk,   SkipOk,   ResultOk   : BOOLEAN;
begin
    inherited execute( AStatus, AContext, aInMsg, aOutMsg );
    System.Finalize( Result );
    ResultNull := TRUE;
    ResultOk   := FALSE;

    TextOk        := RoutineContext.ReadInputString(  AStatus, TReplaceFunction.INPUT_FIELD_TEXT,        Text,        TextNull        );
    PatternOk     := RoutineContext.ReadInputString(  AStatus, TReplaceFunction.INPUT_FIELD_PATTERN,     Pattern,     PatternNull     );
    ReplacementOk := RoutineContext.ReadInputString(  AStatus, TReplaceFunction.INPUT_FIELD_REPLACEMENT, Replacement, ReplacementNull );
    AmountOk      := RoutineContext.ReadInputLongint( AStatus, TReplaceFunction.INPUT_FIELD_AMOUNT,      Amount,      AmountNull      );
    SkipOk        := RoutineContext.ReadInputLongint( AStatus, TReplaceFunction.INPUT_FIELD_SKIP,        Skip,        SkipNull        );

    if( AmountNull or ( Amount < 0 ) )then begin
        Amount := $7FFFFFFF;
    end;
    if( SkipNull or ( Skip < 0 ) )then begin
        Skip := 0;
    end;

    ResultNull := TextNull or PatternNull or ReplacementNull;
    if( not ResultNull )then begin
        Result := Replace( Text, Pattern, Replacement, Amount, Skip );
    end;

    ResultOk := RoutineContext.WriteOutputString( AStatus, TReplaceFunction.OUTPUT_FIELD_RESULT, Result, ResultNull );
end;{ TReplaceFunction.execute }

function SubstitutePercents( Match:TMatch; Replacement:UnicodeString; Percents:TMatchCollection ):UnicodeString;
var
    I, PercentNo, Idx, PercentLen : LONGINT;
    Percent : UnicodeString;
begin
    System.Finalize( Result );

    if( Percents.Count = 0 )then begin

        Result := Replacement;

    end else begin

        Idx := 1;

        for I := 0 to Percents.Count - 1 do begin

            Result := Result + Copy( Replacement, Idx, Percents[ I ].Index - Idx );
            Idx    := Percents[ I ].Index;

            if( Percents[ I ].Groups[ 1 ].Length = 0 )then begin //to exclude %%n
                Percent    := Percents[ I ].Value;
                Delete( Percent, 1, 1 );
                PercentNo  := StrToIntDef( Percent, -1 );
                PercentLen := Percents[ I ].Length;
            end else begin
                PercentNo  := -1;
                Idx        := Idx + 1;  //for %%n skip first %
                PercentLen := Percents[ I ].Length - 1;
            end;

            if( PercentNo >= 0 )then begin
                if( PercentNo < Match.Groups.Count  )then begin
                    Result := Result + Match.Groups.Item[ PercentNo ].Value;
                end;
            end else begin
                Result := Result + Copy( Replacement, Idx, PercentLen );
            end;

            Idx := Percents[ I ].Index + Percents[ I ].Length;

        end;
        if( Idx <= Length( Replacement ) )then begin
            Result := Result + Copy( Replacement, Idx, Length( Replacement ) - Idx + 1 );
        end;

    end;
end;{ SubstituteGroups }

function Replace( Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;
const
    regPercents : UnicodeString = '(%)*(%\d+)';
var
    Match    : TMatch;
    Percents : TMatchCollection;
    Rep      : UnicodeString;
    Index, Count, All : LONGINT;
begin
    System.Finalize( Result );
    Percents := TRegEx.Matches( Replacement, regPercents );
    Index    := 1;
    if( Amount < 0 )then begin
        Amount := $7FFFFFFF;
    end;
    if( Skip < 0 )then begin
        Skip := 0;
    end;
    All   := Amount + Skip;
    Count := 0;

    Match := TRegEx.Create( Pattern, [ roCompiled ] ).Match( Text );
    while( Match.Success and ( Count < All ) )do begin

        Inc( Count );
        if( Count > Skip )then begin

            Rep := SubstitutePercents( Match, Replacement, Percents );

            Result := Result + Copy( Text, Index, Match.Index - Index );
            Index  := Match.Index;
            Result := Result + Rep;
            Index  := Match.Index + Match.Length;

        end;

        Match  := Match.NextMatch;
    end;
    if( Index <= Length( Text ) )then begin
        Result := Result + Copy( Text, Index, Length( Text ) - Index + 1 );
    end;
    Result := Result;
end;{ Replace }


{ plugin call }

var
    myUnloadFlag    : BOOLEAN;
    theirUnloadFlag : BooleanPtr;

function firebird_udr_plugin( AStatus:IStatus; AUnloadFlagLocal:BooleanPtr; AUdrPlugin:IUdrPlugin ):BooleanPtr; cdecl;
begin
    AUdrPlugin.registerProcedure( AStatus, 'matches', TMatchesFactory.Create() );
    AUdrPlugin.registerProcedure( AStatus, 'groups',  TGroupsFactory.Create()  );
    AUdrPlugin.registerFunction(  AStatus, 'replace', TReplaceFactory.Create() );

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
