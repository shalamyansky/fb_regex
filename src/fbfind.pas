(*
    Unit       : fbfind
    Date       : 2022-11-21
    Compiler   : Delphi XE3
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR regular expressions based find functions
    Project    : https://github.com/shalamyansky/fb_regex
    Company    : BWR
*)

//DDL definition
(*
set term ^;

create or alter procedure find(
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
^

create or alter function find_first(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , pass    integer
)returns    varchar(8191) character set UTF8
external name
    'fb_regex!find_first'
engine
    udr
^

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

unit fbfind;

interface

uses
    SysUtils
  , RegularExpressions
  , firebird   // https://github.com/shalamyansky/fb_common
  , fbudr      // https://github.com/shalamyansky/fb_common
;


type

{ find }

TFindFactory = class( TBwrProcedureFactory )
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure; override;
end;{ TFindFactory }

TFindProcedure = class( TBwrSelectiveProcedure )
  const
    INPUT_FIELD_TEXT    = 0;
    INPUT_FIELD_PATTERN = 1;
    INPUT_FIELD_AMOUNT  = 2;
    INPUT_FIELD_SKIP    = 3;
    OUTPUT_FIELD_NUMBER = 0;
    OUTPUT_FIELD_FOUND  = 1;
  public
    function open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet; override;
end;{ TFindProcedure }

TFindResultSet = class( TBwrResultSet )
  private
    fStop   : BOOLEAN;
    fAmount : LONGINT;
    fMatch  : TMatch;
    fNumber : LONGINT;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TFindResultSet }

{ find_first }

TFindFirstFactory = class( TBwrFunctionFactory )
  public
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction; override;
end;{ TFindFirstFactory }

TFindFirstFunction = class( TBwrFunction )
  const
    INPUT_FIELD_TEXT    = 0;
    INPUT_FIELD_PATTERN = 1;
    INPUT_FIELD_SKIP    = 2;
    OUTPUT_FIELD_RESULT = 0;
  public
    procedure execute( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
end;{ TFindFirstFunction }

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

function FindFirst( Text:UnicodeString; Pattern:UnicodeString; Skip:LONGINT = 0 ):UnicodeString; overload;
function Replace( Text:UnicodeString; Pattern:UnicodeString; Replacement:UnicodeString; Amount:LONGINT = $7FFFFFFF; Skip:LONGINT = 0 ):UnicodeString; overload;


implementation


{ TSplitWordsFactory }

function TFindFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TFindProcedure.create( AMetadata );
end;{ TFindFactory.newItem }

{ TFindProcedure }

function TFindProcedure.open( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER ):IExternalResultSet;
begin
    inherited open( AStatus, AContext, aInMsg, aOutMsg );
    Result := TFindResultSet.create( Self, AStatus, AContext, AInMsg, AOutMsg );
end;{ TFindProcedure.open }

{ TSplitWordsResultSet }

constructor TFindResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER );
var
    Text,     Pattern : UnicodeString;
    Skip              : LONGINT;
    TextNull, PatternNull, AmountNull, SkipNull : WORDBOOL;
    TextOk,   PatternOk,   AmountOk,   SkipOk   : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus, AContext, AInMsg, AOutMsg );

    TextOk    := RoutineContext.ReadInputString(  AStatus, TFindProcedure.INPUT_FIELD_TEXT,    Text,    TextNull    );
    PatternOk := RoutineContext.ReadInputString(  AStatus, TFindProcedure.INPUT_FIELD_PATTERN, Pattern, PatternNull );
    AmountOk  := RoutineContext.ReadInputLongint( AStatus, TFindProcedure.INPUT_FIELD_AMOUNT,  fAmount, AmountNull  );
    SkipOk    := RoutineContext.ReadInputLongint( AStatus, TFindProcedure.INPUT_FIELD_SKIP,    Skip,    SkipNull    );
    if( AmountNull or ( fAmount < 0 ) )then begin
        fAmount := $7FFFFFFF;
    end;
    if( SkipNull or ( Skip < 0 ) )then begin
        Skip := 0;
    end;
    fStop := TextNull or ( Length( Text ) = 0 ) or PatternNull or ( Length( Pattern ) = 0 ) or ( fAmount = 0 );
    if( not fStop )then begin
        fMatch  := TRegEx.Create( Pattern, [ roCompiled ] ).Match( Text );
        while( ( Skip > 0 ) and fMatch.Success )do begin
            Dec( Skip );
            fMatch := fMatch.NextMatch;
        end;
        fStop   := not fMatch.Success;
        fNumber := 0;
    end;
end;{ TFindResultSet.Create }

function TFindResultSet.fetch( AStatus:IStatus ):BOOLEAN;
var
    NumberNull : WORDBOOL;
    NumberOk   : BOOLEAN;
    Found      : UnicodeString;
    FoundNull  : WORDBOOL;
    FoundOk    : BOOLEAN;
begin
    if( ( not fStop ) and fMatch.Success )then begin
        Found      := fMatch.Value;
        FoundNull  := FALSE;
        Inc( fNumber );
        NumberNull := FALSE;
        Result     := TRUE;
        fStop      := ( fNumber >= fAmount );

        fMatch := fMatch.NextMatch;
    end else begin
        Found      := '';
        FoundNull  := TRUE;
        fNumber    := 0;
        NumberNull := TRUE;
        Result     := FALSE;
        fStop      := TRUE;
    end;
    NumberOk := RoutineContext.WriteOutputLongint( AStatus, TFindProcedure.OUTPUT_FIELD_NUMBER, fNumber, NumberNull );
    FoundOk  := RoutineContext.WriteOutputString(  AStatus, TFindProcedure.OUTPUT_FIELD_FOUND,  Found,   FoundNull  );
end;{ TFindResultSet.fetch }


{ TFindFirstFactory }

function TFindFirstFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction;
begin
    Result := TFindFirstFunction.create( AMetadata );
end;{ TFindFirstFactory.newItem }

{ TFindFirstFunction }

procedure TFindFirstFunction.execute( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER );
var
    Text, Pattern, Result : UnicodeString;
    Skip : LONGINT;
    TextNull, PatternNull, SkipNull, ResultNull : WORDBOOL;
    TextOk,   PatternOk,   SkipOk,   ResultOk   : BOOLEAN;
begin
    inherited execute( AStatus, AContext, aInMsg, aOutMsg );
    System.Finalize( Result );
    ResultNull := TRUE;
    ResultOk   := FALSE;

    TextOk    := RoutineContext.ReadInputString(  AStatus, TFindFirstFunction.INPUT_FIELD_TEXT,    Text,    TextNull    );
    PatternOk := RoutineContext.ReadInputString(  AStatus, TFindFirstFunction.INPUT_FIELD_PATTERN, Pattern, PatternNull );
    SkipOk    := RoutineContext.ReadInputLongint( AStatus, TFindFirstFunction.INPUT_FIELD_SKIP,    Skip,    SkipNull    );

    if( SkipNull or ( Skip < 0 ) )then begin
        Skip := 0;
    end;

    ResultNull := TextNull or ( Length( Text ) = 0 ) or PatternNull or ( Length( Pattern ) = 0 );
    if( not ResultNull )then begin
        Result     := FindFirst( Text, Pattern, Skip );
        ResultNull := ( Length( Result ) = 0 );
    end;

    ResultOk := RoutineContext.WriteOutputString( AStatus, TFindFirstFunction.OUTPUT_FIELD_RESULT, Result, ResultNull );
end;{ TFindFirstFunction.execute }

function FindFirst( Text:UnicodeString; Pattern:UnicodeString; Skip:LONGINT = 0 ):UnicodeString; overload;
var
    Match : TMatch;
    Start : LONGINT;
    Head , Tail : UnicodeString;
begin
    Result := '';
    if( ( Length( Text ) = 0 ) or ( Length( Pattern ) = 0 ) )then begin
        exit;
    end;
    if( Skip < 0 )then begin
        Skip := 0;
    end;
    Match := TRegEx.Create( Pattern, [ roCompiled ] ).Match( Text );
    while( ( Skip > 0 ) and ( Match.Success ) )do begin
        Dec( Skip );
        Match := Match.NextMatch;
    end;
    if( Match.Success )then begin
        Result := Match.Value;
    end;
end;{ FindFirst }

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

end.
