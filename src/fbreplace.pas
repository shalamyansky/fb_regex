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

function Replace(   Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;
function ReplaceEx( Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;


implementation

uses
    StrUtils
;

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
        Result := ReplaceEx( Text, Pattern, Replacement, Amount, Skip );
    end;

    ResultOk := RoutineContext.WriteOutputString( AStatus, TReplaceFunction.OUTPUT_FIELD_RESULT, Result, ResultNull );
end;{ TReplaceFunction.execute }

function Replace( Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;
var
    RegEx : TRegEx;
    Match : TMatch;
    Start : LONGINT;
    Head , Tail : UnicodeString;
begin
    Result := Text;
    if( ( Length( Text ) = 0 ) or ( Length( Pattern ) = 0 ) )then begin
        exit;
    end;
    if( Amount < 0 )then begin
        Amount := $7FFFFFFF;
    end;
    if( Skip < 0 )then begin
        Skip := 0;
    end;
    RegEx := TRegEx.Create( Pattern, [ roCompiled ] );
    if( Skip = 0 )then begin
        Result := RegEx.Replace( Text, Replacement, Amount );
    end else begin
        Match := RegEx.Match( Text );
        Dec( Skip );
        while( ( Skip > 0 ) and Match.Success )do begin
            Match := Match.NextMatch;
            Dec( Skip );
        end;
        if( Match.Success )then begin
            Start  := Match.Index + Match.Length;
            Head   := Copy( Text, 1, Start - 1 );
            Tail   := Copy( Text, Start );
            Result := Head + RegEx.Replace( Tail, Replacement, Amount );
        end;
    end;
end;{ Replace }

{ ReplaceEx }

{ TCondition }

type

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

function ReplaceEx( Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;
var
    RegEx, RegExRep : TRegEx;
    Match           : TMatch;
    Start, Pos      : LONGINT;
    Conditions      : TConditions;
    MatchReplacement, MatchReplaced : UnicodeString;
    Builder         : TStringBuilder;
begin
    Result := Text;
    if( ( Length( Text ) = 0 ) or ( Length( Pattern ) = 0 ) )then begin
        exit;
    end;
    System.Finalize( Conditions );
    Builder := nil;
    try
        Conditions := PrepareConditions( Replacement );
        if( Length( Conditions ) = 0 )then begin
            //standard replacement without conditions
            Result := Replace( Text, Pattern, Replacement, Amount, Skip );
        end else begin
            if( Amount < 0 )then begin
                Amount := $7FFFFFFF;
            end;
            if( Skip < 0 )then begin
                Skip := 0;
            end;
            RegEx    := TRegEx.Create( Pattern, [ roCompiled ] ); //to seek matches
            RegExRep := TRegEx.Create( Pattern, [ roCompiled ] ); //to replace each match with its replacement
            Builder  := TStringBuilder.Create( 16384 );
            Pos      := 0;
            Match    := RegEx.Match( Text );
            while( ( Amount > 0 ) and Match.Success )do begin
                if( Skip = 0 )then begin
                    MatchReplacement := MakeMatchReplacement( Match, Replacement, Conditions );
                    MatchReplaced    := RegExRep.Replace( Match.Value, MatchReplacement );
                    //StringBuilder.Append( , Pos ) suddenly adds low(string)=1 to Pos (?!)
                    Builder
                        .Append( Text, Pos, Match.Index - 1 - Pos )
                        .Append( MatchReplaced )
                    ;
                    Dec( Amount );
                end else begin
                    Builder.Append( Text, Pos, Match.Index + Match.Length - 1 - Pos );
                    Dec( Skip );
                end;
                Pos   := Match.Index + Match.Length - 1;
                Match := Match.NextMatch;
            end;
            Builder.Append( Text, Pos );
            Result := Builder.ToString;
        end;
    finally
        FreeAndNil( Builder );
        FreeConditions( Conditions );
    end;
end;{ ReplaceEx }


end.
