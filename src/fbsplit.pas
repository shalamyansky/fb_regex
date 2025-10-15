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
  protected
    class function GetBwrResultSetClass:TBwrResultSetClass; override;
end;{ TSplitWordsProcedure }

TSplitWordsResultSet = class( TBwrResultSet )
  private
    fMatch  : TMatch;
    fNumber : LONGINT;
    fRegEx  : TRegEx;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    destructor  Destroy; override;
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
  protected
    class function GetBwrResultSetClass:TBwrResultSetClass; override;
end;{ TSplitProcedure }

TSplitResultSet = class( TBwrResultSet )
  private
    fText   : UnicodeString;
    fStop   : BOOLEAN;
    fPrev   : LONGINT;
    fMatch  : TMatch;
    fNumber : LONGINT;
    fRegEx  : TRegEx;
  public
    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;
    destructor  Destroy; override;
    function fetch( AStatus:IStatus ):BOOLEAN; override;
end;{ TSplitsWordResultSet }


implementation


{ TSplitWordsFactory }

function TSplitWordsFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TSplitWordsProcedure.create( AMetadata );
end;{ TSplitWordsFactory.newItem }


{ TSplitWordsProcedure }

class function TSplitWordsProcedure.GetBwrResultSetClass:TBwrResultSetClass;
begin
    Result := TSplitWordsResultSet;
end;{ TSplitWordsProcedure.GetBwrResultSetClass }


{ TSplitWordsResultSet }

constructor TSplitWordsResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER );
const
    regWord = '[_0-9A-Za-zÀ-ßà-ÿ¨¸]+';
var
    Text     : UnicodeString;
    TextNull : WORDBOOL;
    TextOk   : BOOLEAN;
begin
    inherited Create( ASelectiveProcedure, AStatus, AContext, AInMsg, AOutMsg );

    TextOk  := RoutineContext.ReadInputString( AStatus, TSplitWordsProcedure.INPUT_FIELD_TEXT, Text, TextNull );

    fRegEx  := TRegEx.Create( regWord, [ roCompiled ] );
    fMatch  := fRegEx.Match( Text );
    fNumber := 0;
end;{ TSplitWordsResultSet.Create }

destructor TSplitWordsResultSet.Destroy;
begin
    System.Finalize( fMatch );
    System.Finalize( fRegEx );
    inherited Destroy;
end;{ TSplitWordsResultSet.Destroy }

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

class function TSplitProcedure.GetBwrResultSetClass:TBwrResultSetClass;
begin
    Result := TSplitResultSet;
end;{ TSplitProcedure.GetBwrResultSetClass }


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
        fRegEx  := TRegEx.Create( Separator, [ roCompiled ] );
        fMatch  := fRegEx.Match( fText );
        fNumber := 0;
    end;
end;{ TSplitResultSet.Create }

destructor TSplitResultSet.Destroy;
begin
    System.Finalize( fMatch );
    System.Finalize( fRegEx );
    inherited Destroy;
end;{ TSplitResultSet.Destroy }

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


end.
