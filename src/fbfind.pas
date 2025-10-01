(*
    Unit       : fbfind
    Date       : 2022-11-21
    Compiler   : Delphi XE3, Delphi 12
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
  protected
    class function GetBwrResultSetClass:TBwrResultSetClass; override;
end;{ TFindProcedure }

TFindResultSet = class( TBwrResultSet )
  private
    fStop   : BOOLEAN;
    fAmount : LONGINT;
    fMatch  : TMatch;
    fNumber : LONGINT;
    fRegEx  : TRegEx;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    destructor  Destroy; override;
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


function FindFirst( Text:UnicodeString; Pattern:UnicodeString; Skip:LONGINT = 0 ):UnicodeString; overload;


implementation


{ TFindProcedureFactory }

function TFindFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TFindProcedure.create( AMetadata );
end;{ TFindFactory.newItem }


{ TFindProcedure }

class function TFindProcedure.GetBwrResultSetClass:TBwrResultSetClass;
begin
    Result := TFindResultSet;
end;{ TFindProcedure.GetBwrResultSetClass }


{ TFindResultSet }

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
        fRegEx  := TRegEx.Create( Pattern, [ roCompiled ] );
        fMatch  := fRegEx.Match( Text );
        while( ( Skip > 0 ) and fMatch.Success )do begin
            Dec( Skip );
            fMatch := fMatch.NextMatch;
        end;
        fStop   := not fMatch.Success;
        fNumber := 0;
    end;
end;{ TFindResultSet.Create }

destructor TFindResultSet.Destroy;
begin
    System.Finalize( fRegEx );
    inherited Destroy;
end;{ TFindResultSet.Destroy }

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
    RegEx : TRegEx;
begin
    Result := '';
    if( ( Length( Text ) = 0 ) or ( Length( Pattern ) = 0 ) )then begin
        exit;
    end;
    if( Skip < 0 )then begin
        Skip := 0;
    end;
    RegEx := TRegEx.Create( Pattern, [ roCompiled ] );
    Match := RegEx.Match( Text );
    while( ( Skip > 0 ) and ( Match.Success ) )do begin
        Dec( Skip );
        Match := Match.NextMatch;
    end;
    if( Match.Success )then begin
        Result := Match.Value;
    end;
    System.Finalize( RegEx );
end;{ FindFirst }


end.
