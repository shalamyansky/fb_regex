(*
    Unit       : fbsplit
    Date       : 2022-11-09
    Compiler   : Delphi XE3, Delphi 12
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR regular expressions based split functions
    Project    : https://github.com/shalamyansky/fb_regex
    Company    : BWR
*)

//DDL definition
(*
set term ^;

create or alter procedure split(
    text      varchar(8191) character set UTF8
  , separator varchar(8191) character set UTF8
)returns(
    number    integer
  , part      varchar(8191) character set UTF8
)external name
    'fb_regex!split'
engine
    udr
^

create or alter procedure split_words(
    text   varchar(8191) character set UTF8
)returns(
    number integer
  , word   varchar(8191) character set UTF8
)external name
    'fb_regex!split_words'
engine
    udr
^

set term ;^
*)

unit fbsplit;

interface

uses
    SysUtils
  , RegularExpressions
  , firebird     // https://github.com/shalamyansky/fb_common
  , fbudr        // https://github.com/shalamyansky/fb_common
;


type

{ split_words }

TSplitWordsFactory = class( TBwrProcedureFactory )
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure; override;
end;{ TSplitWordsFactory }

TSplitWordsProcedure = class( TBwrSelectiveProcedure )
  const
    INPUT_FIELD_TEXT    = 0;
    OUTPUT_FIELD_NUMBER = 0;
    OUTPUT_FIELD_WORD   = 1;
  public
    function open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet; override;
end;{ TSplitWordsProcedure }

TSplitWordsResultSet = class( TBwrResultSet )
  private
    fMatch  : TMatch;
    fNumber : LONGINT;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TSplitsWordResultSet }

{ split }

TSplitFactory = class( TBwrProcedureFactory )
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure; override;
end;{ TSplitFactory }

TSplitProcedure = class( TBwrSelectiveProcedure )
  const
    INPUT_FIELD_TEXT      = 0;
    INPUT_FIELD_SEPARATOR = 1;
    OUTPUT_FIELD_NUMBER   = 0;
    OUTPUT_FIELD_PART     = 1;
  public
    function open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet; override;
end;{ TSplitProcedure }

TSplitResultSet = class( TBwrResultSet )
  private
    fText   : UnicodeString;
    fStop   : BOOLEAN;
    fPrev   : LONGINT;
    fMatch  : TMatch;
    fNumber : LONGINT;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TSplitsWordResultSet }


implementation


const
    regWord : UnicodeString = '[0-9A-Za-zÀ-ßà-ÿ¨¸]+';
var
    prnWord : TRegEx;

{ TSplitWordsFactory }

function TSplitWordsFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TSplitWordsProcedure.create( AMetadata );
end;{ TSplitWordsFactory.newItem }

{ TSplitWordsProcedure }

function TSplitWordsProcedure.open( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER ):IExternalResultSet;
begin
    inherited open( AStatus, AContext, aInMsg, aOutMsg );
    Result := TSplitWordsResultSet.create( Self, AStatus, AContext, AInMsg, AOutMsg );
end;{ TSplitWordsProcedure.open }

{ TSplitWordsResultSet }

constructor TSplitWordsResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER );
var
    Text     : UnicodeString;
    TextNull : WORDBOOL;
    TextOk   : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus, AContext, AInMsg, AOutMsg );

    TextOk  := RoutineContext.ReadInputString( AStatus, TSplitWordsProcedure.INPUT_FIELD_TEXT, Text, TextNull );

    fMatch  := prnWord.Match( Text );
    fNumber := 0;
end;{ TSplitWordsResultSet.Create }

function TSplitWordsResultSet.fetch( AStatus:IStatus ):BOOLEAN;
var
    NumberNull : WORDBOOL;
    NumberOk   : BOOLEAN;
    Word       : UnicodeString;
    WordNull   : WORDBOOL;
    WordOk     : BOOLEAN;
begin
    Result := fMatch.Success;
    if( Result )then begin
        Inc( fNumber );
        NumberNull := FALSE;
        Word       := fMatch.Value;
        WordNull   := FALSE;

        fMatch := fMatch.NextMatch;
    end else begin
        fNumber    := 0;
        NumberNull := TRUE;
        Word     := '';
        WordNull := TRUE;
    end;
    NumberOk := RoutineContext.WriteOutputLongint( AStatus, TSplitWordsProcedure.OUTPUT_FIELD_NUMBER, fNumber, NumberNull );
    WordOk   := RoutineContext.WriteOutputString(  AStatus, TSplitWordsProcedure.OUTPUT_FIELD_WORD,   Word,    WordNull   );
end;{ TSplitWordsResultSet.fetch }

{ TSplitFactory }

function TSplitFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TSplitProcedure.create( AMetadata );
end;{ TSplitFactory.newItem }

{ TSplitProcedure }

function TSplitProcedure.open( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER ):IExternalResultSet;
begin
    inherited open( AStatus, AContext, aInMsg, aOutMsg );
    Result := TSplitResultSet.create( Self, AStatus, AContext, AInMsg, AOutMsg );
end;{ TSplitProcedure.open }

{ TSplitWordsResultSet }

constructor TSplitResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER );
var
              Separator     : UnicodeString;
    TextNull, SeparatorNull : WORDBOOL;
    TextOk,   SeparatorOk   : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus, AContext, AInMsg, AOutMsg );

    TextOk      := RoutineContext.ReadInputString( AStatus, TSplitProcedure.INPUT_FIELD_TEXT,      fText,     TextNull );
    SeparatorOk := RoutineContext.ReadInputString( AStatus, TSplitProcedure.INPUT_FIELD_SEPARATOR, Separator, SeparatorNull );

    fStop := TextNull or ( Length( fText ) = 0 ) or SeparatorNull or ( Length( Separator ) = 0 );
    if( not fStop )then begin
        fPrev   := 1;
        fMatch  := TRegEx.Create( Separator, [ roCompiled ] ).Match( fText );
        fNumber := 0;
    end;
end;{ TSplitResultSet.Create }

function TSplitResultSet.fetch( AStatus:IStatus ):BOOLEAN;
var
    NumberNull : WORDBOOL;
    NumberOk   : BOOLEAN;
    Part       : UnicodeString;
    PartNull   : WORDBOOL;
    PartOk     : BOOLEAN;
    PartLen    : LONGINT;
begin
    if( fStop )then begin
        Result     := FALSE;
        Part       := '';
        PartNull   := TRUE;
        fNumber    := 0;
        NumberNull := TRUE;
    end else begin
        if( fMatch.Success )then begin
            Part     := Copy( fText, fPrev, fMatch.Index - fPrev );
            PartNull := ( Length( Part ) = 0 );
            Result   := TRUE;

            fPrev  := fMatch.Index + fMatch.Length;
            fMatch := fMatch.NextMatch;
        end else begin
            Part     := Copy( fText, fPrev );
            PartNull := ( Length( Part ) = 0 );
            Result   := TRUE;
            fStop    := TRUE;
        end;
        Inc( fNumber );
        NumberNull := FALSE;
    end;
    NumberOk := RoutineContext.WriteOutputLongint( AStatus, TSplitProcedure.OUTPUT_FIELD_NUMBER, fNumber, NumberNull );
    PartOk   := RoutineContext.WriteOutputString(  AStatus, TSplitProcedure.OUTPUT_FIELD_PART,   Part,    PartNull   );
end;{ TMatchesResultSet.fetch }

procedure InitalizationProc;
begin
    prnWord := TRegEx.Create( regWord, [ roCompiled ] );
end;{ InitalizationProc }

initialization
begin
    InitalizationProc;
end;



end.
