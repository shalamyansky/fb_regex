(*
    Unit       : fbreplace
    Date       : 2025-08-25
    Compiler   : Delphi XE3, Delphi 12
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR regular expressions based find functions
    Project    : https://github.com/shalamyansky/fb_regex
    Company    : BWR
*)

//DDL definition
(*
set term ^;

create or alter function replace(
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
^

create or alter procedure substitute(
    text        varchar(8191) character set UTF8
  , pattern     varchar(8191) character set UTF8
  , replacement varchar(8191) character set UTF8
  , amount      integer
  , pass        integer
)returns(
    modified    varchar(8191) character set UTF8
  , replaced    integer
)external name
    'fb_regex!replace'
engine
    udr
^

set term ;^
*)

unit fbreplace;

interface

uses
    SysUtils
  , RegularExpressions
  , firebird   // https://github.com/shalamyansky/fb_common
  , fbudr      // https://github.com/shalamyansky/fb_common
;


type

{ TCondition }

TCondition = class;
TConditions = array of TCondition;
TCondition = class
  private
    Start    : LONGINT;
    Length   : LONGINT;
    GroupNo  : LONGINT;
    Present  : UnicodeString;
    PreConds : TConditions;
    Absent   : UnicodeString;
    AbsConds : TConditions;
  public
    constructor Create; overload;
    constructor Create( Start, Length, GroupNo : LONGINT ); overload;
    destructor  Destroy; override;
end;{ TCondition }

{ TReplaceCounter }

TReplaceCounter = class
  private
    fSkip        : LONGINT;
    fAmount      : LONGINT;
    fCount       : LONGINT;
    fReplacement : UnicodeString;
    fConditions  : TConditions;
  public
    constructor Create( const Replacement:UnicodeString; Amount:LONGINT; Skip:LONGINT );
    destructor Destroy; override;
    function Evaluate( const Match:TMatch ):UnicodeString;
    property Amount:LONGINT read fAmount write fAmount;
    property Skip:LONGINT   read fSkip   write fSkip;
    property Count:LONGINT  read fCount;
end;{ TReplaceCounter }


{ TReplaceFunction }

TReplaceFunctionFactory = class( TBwrFunctionFactory )
  public
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction; override;
end;{ TReplaceFunctionFactory }

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


{ TSubstituteProcedure }

TSubstituteProcedureFactory = class( TBwrProcedureFactory )
  public
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure; override;
end;{ TSubstituteProcedureFactory }

TSubstituteProcedure = class( TBwrSelectiveProcedure )
  const
    INPUT_FIELD_TEXT        = 0;
    INPUT_FIELD_PATTERN     = 1;
    INPUT_FIELD_REPLACEMENT = 2;
    INPUT_FIELD_AMOUNT      = 3;
    INPUT_FIELD_SKIP        = 4;
    OUTPUT_FIELD_RESULT     = 0;
    OUTPUT_FIELD_COUNT      = 1;
  protected
    class function GetBwrResultSetClass:TBwrResultSetClass; override;
end;{ TSubstituteProcedure }

TSubstituteResultSet = class( TBwrResultSet )
  private
    fDone : BOOLEAN;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TSubstituteResultSet }


function Replace(  Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; out Replaced:LONGINT; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;


implementation

uses
    StrUtils
;

{ REGION TCondition}
{$REGION TCondition}
constructor TCondition.Create;
begin
    inherited Create;
    GroupNo := -1;
end;{ TCondition.Create }

constructor TCondition.Create( Start, Length, GroupNo : LONGINT );
begin
    Self.Start   := Start;
    Self.Length  := Length;
    Self.GroupNo := GroupNo;
end;{ TCondition.Create }

procedure FreeConditions( var Conditions:TConditions );
var
    I : LONGINT;
begin
    for I := Length( Conditions ) - 1 downto 0 do begin
        FreeAndNil( Conditions[ I ] );
    end;
    System.Finalize( Conditions );
end;{ FreeConditions }

destructor TCondition.Destroy;
begin
    FreeConditions( AbsConds );
    FreeConditions( PreConds );
    inherited Destroy;
end;{ TCondition.Destroy }

procedure ArrayAppend( Value:TCondition; var Arr:TConditions );
var
    L : LONGINT;
begin
    L := Length( Arr );
    SetLength( Arr, Succ( L ) );
    Arr[ L ] := Value;
end;{ ArrayAppend }

function PrepareConditions( Replacement:UnicodeString ):TConditions;
const
    cndPattern = '\$(\{(?:(\d{1,2}):([+-]))?((?:(?1)|.)*?)(?::((?:(?1)|.)*?))?\})';
    grpNumber  = 2;
    grpSign    = 3;
    grpPresent = 4;
    grpAbsent  = 5;
var
    cndRegEx  : TRegEx;
    Condition : TCondition;
    GroupNo   : LONGINT;
    Match     : TMatch;
    Sign      : UnicodeString;
    Reverse   : BOOLEAN;
begin
    System.Finalize( Result );
    cndRegEx := TRegEx.Create( cndPattern, [ roCompiled ] );
    Match    := cndRegEx.Match( Replacement );
    while( Match.Success )do begin

        GroupNo := -1;
        if( ( grpNumber < Match.Groups.Count ) and Match.Groups.Item[ grpNumber ].Success )then begin
            GroupNo := StrToIntDef(                Match.Groups.Item[ grpNumber ].Value, -1 );
        end;
        if( GroupNo >= 0 )then begin
            Condition := TCondition.Create( Match.Index, Match.Length, GroupNo );
            Reverse   := FALSE;
            if( ( grpSign < Match.Groups.Count ) and Match.Groups.Item[ grpSign ].Success )then begin
                Reverse := SameStr(                  Match.Groups.Item[ grpSign ].Value, '-' );
            end;
            if( ( grpPresent < Match.Groups.Count ) and Match.Groups.Item[ grpPresent ].Success )then begin
                case Reverse of
                    FALSE : Condition.Present := Match.Groups.Item[ grpPresent ].Value;
                    TRUE  : Condition.Absent  := Match.Groups.Item[ grpPresent ].Value;
                end;
            end;
            if( ( grpAbsent < Match.Groups.Count ) and Match.Groups.Item[ grpAbsent ].Success )then begin
                case Reverse of
                    FALSE : Condition.Absent  := Match.Groups.Item[ grpAbsent ].Value;
                    TRUE  : Condition.Present := Match.Groups.Item[ grpAbsent ].Value;
                end;
            end;
            Condition.PreConds := PrepareConditions( Condition.Present );
            Condition.AbsConds := PrepareConditions( Condition.Absent  );

            ArrayAppend( Condition, Result );
        end;

        Match := Match.NextMatch;
    end;
    System.Finalize( cndRegEx );
end;{ PrepareConditions }
{$ENDREGION TCondition}

function MakeMatchReplacement( Match:TMatch; Replacement:UnicodeString; Conditions:TConditions ):UnicodeString;
var
    I : LONGINT;
    Condition : TCondition;
begin
    Result := Replacement;
    for I := Length( Conditions ) - 1 downto 0 do begin
        Condition := Conditions[ I ];
        Result := StuffString(
            Result
          , Condition.Start
          , Condition.Length
          , IfThen(
              (
                    ( Condition.GroupNo < Match.Groups.Count )
                and Match.Groups.Item[ Condition.GroupNo ].Success
                and ( 0 < Length( Match.Groups.Item[ Condition.GroupNo ].Value ) )
              )
            , MakeMatchReplacement( Match, Condition.Present, Condition.PreConds )
            , MakeMatchReplacement( Match, Condition.Absent,  Condition.AbsConds )
          )
        );
    end;
end;{ MakeMatchReplacement }

{ REGION TReplaceCounter }
{$REGION TReplaceCounter }
constructor TReplaceCounter.Create( const Replacement:UnicodeString; Amount:LONGINT; Skip:LONGINT );
begin
    inherited Create;
    fReplacement := Replacement;
    fAmount      := Amount;
    if( fAmount < 0 )then begin
        fAmount  := $7FFFFFFF;
    end;
    fSkip        := Skip;
    if( fSkip < 0 )then begin
        fSkip    := 0;
    end;
    fConditions := PrepareConditions( Replacement );
    fCount      := 0;
end;{ TReplaceCounter.Create }

function TReplaceCounter.Evaluate( const Match:TMatch ):UnicodeString;
var
    LocalReplacement : UnicodeString;
begin
    System.Finalize( Result );
    if( fSkip > 0 )then begin
        Dec( fSkip );
        Result := Match.Value;
    end else if( fCount >= fAmount )then begin
        Result := Match.Value;
    end else begin
        if( Length( fConditions ) = 0 )then begin
            LocalReplacement := fReplacement;
        end else begin
            LocalReplacement := MakeMatchReplacement( Match, fReplacement, fConditions );
        end;
        Result := Match.Result( LocalReplacement );
        Inc( fCount );
    end;
end;{ TReplaceCounter.Evaluate }

destructor TReplaceCounter.Destroy;
begin
    FreeConditions( fConditions );
    inherited Destroy;
end;{ TReplaceCounter.Destroy }

{$ENDREGION TReplaceCounter }

function Replace( Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; out Replaced:LONGINT; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;
var
    RegEx   : TRegEx;
    Counter : TReplaceCounter;
begin
    Result   := Text;
    Replaced := 0;
    if( ( Length( Text ) = 0 ) or ( Length( Pattern ) = 0 ) )then begin
        exit;
    end;
    try
        Counter  := nil;
        Counter  := TReplaceCounter.Create( Replacement, Amount, Skip );
        RegEx    := TRegEx.Create( Pattern, [ roCompiled ] );

        Result   := RegEx.Replace( Text, Counter.Evaluate );
        Replaced := Counter.Count;
    finally
        System.Finalize( RegEx );
        FreeAndNil( Counter );
    end;
end;{ Replace }


{ REGION TReplaceFunction }
{$REGION TReplaceFunction}

{ TReplaceFactory }

function TReplaceFunctionFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction;
begin
    Result := TReplaceFunction.create( AMetadata );
end;{ TReplaceFunctionFactory.newItem }

{ TReplaceFunction }

procedure TReplaceFunction.execute( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER );
var
    Text, Pattern, Replacement, Result : UnicodeString;
    Amount, Skip, Replaced : LONGINT;
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

    ResultNull := TextNull or PatternNull;
    if( not ResultNull )then begin
        Result := Replace( Text, Pattern, Replacement, Replaced, Amount, Skip );
    end;

    ResultOk := RoutineContext.WriteOutputString( AStatus, TReplaceFunction.OUTPUT_FIELD_RESULT, Result, ResultNull );
end;{ TReplaceFunction.execute }

{$ENDREGION TReplaceFunction}

{ REGION TSubstituteProcedure }
{$REGION TSubstituteProcedure}

{ TSubstituteFactory }

function TSubstituteProcedureFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TSubstituteProcedure.create( AMetadata );
end;{ TSubstituteProcedureFactory.newItem }

{ TSubstituteProcedure }

class function TSubstituteProcedure.GetBwrResultSetClass:TBwrResultSetClass;
begin
    Result := TSubstituteResultSet;
end;{ TSubstituteProcedure.GetBwrResultSetClass }

{ TSubstituteResultSet }

constructor TSubstituteResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER );
begin
    inherited Create( ASelectiveProcedure, AStatus, AContext, AInMsg, AOutMsg );
    fDone := FALSE;
end;{ TSubstituteResultSet.Create }

function TSubstituteResultSet.fetch( AStatus:IStatus ):BOOLEAN;
var
    Text, Pattern, Replacement, Modified : UnicodeString;
    Amount, Skip, Count                  : LONGINT;
    TextNull, PatternNull, ReplacementNull, AmountNull, SkipNull, ModifiedNull, CountNull : WORDBOOL;
    TextOk,   PatternOk,   ReplacementOk,   AmountOk,   SkipOk,   ModifiedOk,   CountOk   : BOOLEAN;
begin
    Result := not fDone; //single row only
    if( fDone )then begin
        exit;
    end;
    ModifiedNull := TRUE;
    CountNull    := TRUE;
    System.Finalize( Modified );
    Count        := 0;

    TextOk        := RoutineContext.ReadInputString(  AStatus, TSubstituteProcedure.INPUT_FIELD_TEXT,        Text,        TextNull        );
    PatternOk     := RoutineContext.ReadInputString(  AStatus, TSubstituteProcedure.INPUT_FIELD_PATTERN,     Pattern,     PatternNull     );
    ReplacementOk := RoutineContext.ReadInputString(  AStatus, TSubstituteProcedure.INPUT_FIELD_REPLACEMENT, Replacement, ReplacementNull );
    AmountOk      := RoutineContext.ReadInputLongint( AStatus, TSubstituteProcedure.INPUT_FIELD_AMOUNT,      Amount,      AmountNull      );
    SkipOk        := RoutineContext.ReadInputLongint( AStatus, TSubstituteProcedure.INPUT_FIELD_SKIP,        Skip,        SkipNull        );
    if( AmountNull or ( Amount < 0 ) )then begin
        Amount := $7FFFFFFF;
    end;
    if( SkipNull or ( Skip < 0 ) )then begin
        Skip := 0;
    end;

    if( ( not TextNull ) and ( not PatternNull ) )then begin

        Modified     := Replace( Text, Pattern, Replacement, Count, Amount, Skip );

        ModifiedNull := FALSE;
        CountNull    := FALSE;

    end;

    ModifiedOk := RoutineContext.WriteOutputString(  AStatus, TSubstituteProcedure.OUTPUT_FIELD_RESULT, Modified, ModifiedNull );
    CountOk    := RoutineContext.WriteOutputLongint( AStatus, TSubstituteProcedure.OUTPUT_FIELD_COUNT,  Count,    CountNull    );

    fDone := TRUE;
end;{ TSubstituteResultSet.fetch }

{$ENDREGION TSubstituteProcedure}


end.
