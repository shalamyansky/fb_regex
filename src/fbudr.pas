(*
    Unit       : fbudr
    Date       : 2022-09-09
    Compiler   : Delphi XE3
    ©Copyright : Shalamyansky Mikhail Arkadievich
    Contents   : Firebird UDR helper classes and utilities
    Company    : BWR
*)
unit fbudr;

interface

uses
    SysUtils
  , Firebird
;

type

//char(32767) character set WIN1251
//32767 max data bytes
CHAR_ANSI = record
    Value : array[ 0..32767 ] of AnsiChar;
end;
PCHAR_ANSI = ^CHAR_ANSI;
CHARS_ANSI = array of CHAR_ANSI;

//char(8191) character set UTF8
//32764 max data bytes + 1 zero byte
CHAR_UTF8 = record
    Value : array[ 0..32764 ] of AnsiChar;
end;
PCHAR_UTF8 = ^CHAR_UTF8;
CHARS_UTF8 = array of CHAR_UTF8;

//varchar(32765) character set WIN1251
//32765 max data bytes
VARCHAR_ANSI = record
    Length : SMALLINT;
    Value  : array[ 0..32764 ] of AnsiChar;
end;
PVARCHAR_ANSI = ^VARCHAR_ANSI;
VARCHARS_ANSI = array of VARCHAR_ANSI;

//varchar(8191) character set UTF8
//32764 max data bytes + 1 zero byte
VARCHAR_UTF8 = record
    Length : SMALLINT;
    Value  : array[ 0..32764 ] of AnsiChar;
end;
PVARCHAR_UTF8 = ^VARCHAR_UTF8;
VARCHARS_UTF8 = array of VARCHAR_UTF8;

TMessageType = (
    INPUT_MESSAGE
  , OUTPUT_MESSAGE
);{ TMessageType }

TFieldMetadata = record
    FieldIndex : UINT32;
    FieldType  : UINT32;
    SubType    : LONGINT;
    Length     : UINT32;
    CharSet    : UINT32;
    Offset     : UINT32;
    NullOffset : UINT32;
end;{ TFieldMetadata }

procedure Finalize( var FieldMetadata:TFieldMetadata ); overload;
procedure Finalize( var v:CHAR_ANSI ); overload;
procedure Finalize( var v:CHAR_UTF8 ); overload;
procedure Finalize( var v:VARCHAR_ANSI ); overload;
procedure Finalize( var v:VARCHAR_UTF8 ); overload;
procedure Finalize( var BlobId:ISC_QUAD ); overload;

function CharToString( const v:CHAR_ANSI; Length:SMALLINT ):AnsiString;    overload;
function CharToString( const v:CHAR_UTF8; Length:SMALLINT ):UnicodeString; overload;

function StringToCharAnsi( const s:UnicodeString; Len:SMALLINT ):CHAR_ANSI;
function StringToCharUtf8( const s:UnicodeString; Len:SMALLINT ):CHAR_UTF8;

function VarcharToString( const v:VARCHAR_ANSI ):UnicodeString; overload;
function VarcharToString( const v:VARCHAR_UTF8 ):UnicodeString; overload;

function StringToVarcharAnsi( const s:UnicodeString; MaxLength:LONGINT = 32765 ):VARCHAR_ANSI;
function StringToVarcharUtf8( const s:UnicodeString; MaxLength:LONGINT =  8191 ):VARCHAR_UTF8;

function ReadBlobBytes( Status:IStatus; Blob:IBlob ):TBytes; overload;
function ReadBlobBytes( Status:IStatus; Context:IExternalContext; BlobId:ISC_QUAD ):TBytes; overload;

function WriteBlobBytes( Status:IStatus; Blob:IBlob; pBytes:PBYTE; bLength:LONGINT ):BOOLEAN; overload;
function WriteBlobBytes( Status:IStatus; Context:IExternalContext; pBlobId:ISC_QUADPtr; pBytes:PBYTE; bLength:LONGINT ):BOOLEAN; overload;

const
    CP_UTF8 = 65001;

{ SQL data types }
{ extracted from \Firebird-4.0.2.2816-0\src\include\firebird\impl\sqlda_pub.h }
    SQL_TEXT            =   452; //FB_CHAR
    SQL_VARYING         =   448; //FB_VARCHAR
    SQL_SHORT           =   500; //FB_SMALLINT
    SQL_LONG            =   496; //FB_INTEGER
    SQL_FLOAT           =   482;
    SQL_DOUBLE          =   480;
    SQL_D_FLOAT         =   530;
    SQL_TIMESTAMP       =   510;
    SQL_DATE            =   510; // = SQL_TIMESTAMP
    SQL_BLOB            =   520; //FB_BLOB
    SQL_ARRAY           =   540;
    SQL_QUAD            =   550;
    SQL_TYPE_TIME       =   560;
    SQL_TYPE_DATE       =   570;
    SQL_INT64           =   580; //FB_BIGINT
    SQL_TIMESTAMP_TZ_EX = 32748;
    SQL_TIME_TZ_EX      = 32750;
    SQL_INT128          = 32752;
    SQL_TIMESTAMP_TZ    = 32754;
    SQL_TIME_TZ         = 32756;
    SQL_DEC16           = 32760;
    SQL_DEC34           = 32762;
    SQL_BOOLEAN         = 32764;
    SQL_NULL            = 32766;
{ Firebird data types }
    FB_SMALLINT         =   500; //SQL_SHORT
    FB_INTEGER          =   496; //SQL_LONG
    FB_BIGINT           =   580; //SQL_INT64
    FB_CHAR             =   452; //SQL_TEXT
    FB_VARCHAR          =   448; //SQL_VARYING
    FB_BLOB             =   520; //SQL_BLOB

    FB_SUBTYPE_BINARY   =     0;
    FB_SUBTYPE_TEXT     =     1;

    FB_CHARSET_UTF8     =     4;
    FB_CHARSET_WIN1251  =    52;


type

TRoutineContext = class
  private
    fRoutineMetadata : IRoutineMetadata;
    fStatus          : IStatus;
    fContext         : IExternalContext;
    fInputMessage    : PAnsiChar;
    fOutputMessage   : PAnsiChar;
  public
    property RoutineMetadata : IRoutineMetadata read fRoutineMetadata;
    property Status          : IStatus          read fStatus;
    property Context         : IExternalContext read fContext;
    property pInputMessage   : PAnsiChar        read fInputMessage;
    property pOutputMessage  : PAnsiChar        read fOutputMessage;

    constructor Create(
        RoutineMetadata : IRoutineMetadata;
        Status          : IStatus;
        Context         : IExternalContext;
        InputMessage    : PAnsiChar;
        OutputMessage   : PAnsiChar
    ); virtual;

    function GetFieldMetadata( Status:IStatus; MessageType:TMessageType; FieldIndex:UINT32; out FieldMetadata:TFieldMetadata ):BOOLEAN;
    function ReadInputOrdinal(  Status:IStatus; FieldIndex:UINT32; out Value:INT64;         out IsNull:WORDBOOL ):BOOLEAN;
    function ReadInputShortint( Status:IStatus; FieldIndex:UINT32; out Value:SMALLINT;      out IsNull:WORDBOOL ):BOOLEAN;
    function ReadInputSmallint( Status:IStatus; FieldIndex:UINT32; out Value:SMALLINT;      out IsNull:WORDBOOL ):BOOLEAN;
    function ReadInputLongint(  Status:IStatus; FieldIndex:UINT32; out Value:LONGINT;       out IsNull:WORDBOOL ):BOOLEAN;
    function ReadInputBigint(   Status:IStatus; FieldIndex:UINT32; out Value:INT64;         out IsNull:WORDBOOL ):BOOLEAN;
    function ReadInputString(   Status:IStatus; FieldIndex:UINT32; out Value:UnicodeString; out IsNull:WORDBOOL ):BOOLEAN;
    function ReadInputBlob(     Status:IStatus; FieldIndex:UINT32; out Value:TBytes;        out IsNull:WORDBOOL ):BOOLEAN;
    function WriteOutputOrdinal(  Status:IStatus; FieldIndex:UINT32; Value:INT64;         IsNull:WORDBOOL ):BOOLEAN;
    function WriteOutputShortint( Status:IStatus; FieldIndex:UINT32; Value:SMALLINT;      IsNull:WORDBOOL ):BOOLEAN;
    function WriteOutputSmallint( Status:IStatus; FieldIndex:UINT32; Value:SMALLINT;      IsNull:WORDBOOL ):BOOLEAN;
    function WriteOutputLongint(  Status:IStatus; FieldIndex:UINT32; Value:LONGINT;       IsNull:WORDBOOL ):BOOLEAN;
    function WriteOutputBigint(   Status:IStatus; FieldIndex:UINT32; Value:INT64;         IsNull:WORDBOOL ):BOOLEAN;
    function WriteOutputString(   Status:IStatus; FieldIndex:UINT32; Value:UnicodeString; IsNull:WORDBOOL ):BOOLEAN;
    function WriteOutputBlob(     Status:IStatus; FieldIndex:UINT32; Value:TBytes;        IsNull:WORDBOOL ):BOOLEAN;

end;{ TRoutineContext }

TBwrProcedureFactory = class( IUdrProcedureFactoryImpl )
    procedure dispose(); override;
    procedure setup( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata; AInBuilder:IMetadataBuilder; AOutBuilder:IMetadataBuilder ); override;
    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure; override;
end;{ TBwrProcedureFactory }

TBwrProcedure = class( IExternalProcedureImpl )

  private

    fRoutineMetadata : IRoutineMetadata;
    fRoutineContext  : TRoutineContext;

  public

    property RoutineMetadata : IRoutineMetadata read fRoutineMetadata;
    property RoutineContext  : TRoutineContext  read fRoutineContext;

    constructor Create( RoutineMetadata:IRoutineMetadata ); virtual;
    destructor Destroy; override;

    procedure dispose(); override;

    procedure getCharSet( AStatus:IStatus; AContext:IExternalContext; AName:PAnsiChar; ANameSize:UINT32 ); override;

    function open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet; override;

end;{ TBwrProcedure }

TBwrSelectiveProcedure = class( TBwrProcedure )
    function open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet; override;
end;{ TBwrSelectiveProcedure }

TBwrResultSet = class( IExternalResultSetImpl )

  private

    fSelectiveProcedure : TBwrSelectiveProcedure;

    function GetRoutineContext():TRoutineContext;

  public

    property SelectiveProcedure : TBwrSelectiveProcedure read fSelectiveProcedure;
    property RoutineContext     : TRoutineContext  read GetRoutineContext;

    constructor Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus ); virtual;

    procedure dispose(); override;

    function fetch( AStatus:IStatus ):BOOLEAN; override;

end;{ TBwrResultSet }

TBwrFunctionFactory = class( IUdrFunctionFactoryImpl )

    procedure dispose(); override;

    procedure setup( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata; AInBuilder:IMetadataBuilder; AOutBuilder:IMetadataBuilder ); override;

    function newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction; override;

end;{ TBwrFunctionFactory }

TBwrFunction = class( IExternalFunctionImpl )

  private

    fRoutineMetadata : IRoutineMetadata;
    fRoutineContext  : TRoutineContext;

  public

    property RoutineMetadata : IRoutineMetadata read fRoutineMetadata;
    property RoutineContext  : TRoutineContext  read fRoutineContext;

    constructor Create( RoutineMetadata:IRoutineMetadata ); virtual;
    destructor Destroy; override;

    procedure dispose(); override;

    procedure getCharSet( AStatus:IStatus; AContext:IExternalContext; AName:PAnsiChar; ANameSize:UINT32 ); override;

    procedure execute( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ); override;

end;{ TBwrFunction }


implementation


procedure Finalize( var FieldMetadata:TFieldMetadata ); overload;
begin
    FillChar( FieldMetadata, SizeOf( FieldMetadata ), 0 );
end;{ Finalize }

procedure Finalize( var v:CHAR_ANSI );
begin
    FillChar( v, SizeOf( v ), 0 );
end;{ Finalize }

procedure Finalize( var v:CHAR_UTF8 );
begin
    FillChar( v, SizeOf( v ), 0 );
end;{ Finalize }

procedure Finalize( var v:VARCHAR_ANSI );
begin
    FillChar( v, SizeOf( v ), 0 );
end;{ Finalize }

procedure Finalize( var v:VARCHAR_UTF8 );
begin
    FillChar( v, SizeOf( v ), 0 );
end;{ Finalize }

procedure Finalize( var BlobId:ISC_QUAD ); overload;
begin
    PUINT64( @BlobId )^ := 0;
end;{ Finalize }

function CharToString( const v:CHAR_ANSI; Length:SMALLINT ):AnsiString;
begin
    System.Finalize( Result );
    if( Length > 0 )then begin
        SetString( Result, PAnsiChar( @v.Value ), Length );
    end;
end;{ VarcharToString }

function CharToString( const v:CHAR_UTF8; Length:SMALLINT ):UnicodeString;
var
    bytes : TBytes;
    Utf8Str : Utf8String;
begin
    System.Finalize( Result );
    System.Finalize( Utf8Str );
    if( Length > 0 )then begin
        SetLength( bytes, Length );
        Move( v.Value, POINTER( bytes )^, Length );
        Utf8Str := TEncoding.UTF8.GetString( bytes );
        Result  := Utf8Str; //converts UTF8 -> UTF16 ?
    end;
end;{ VarcharToString }

function Rightpad( s:AnsiString; Len:LONGINT; Chr:AnsiChar ):AnsiString;
var
    Count : LONGINT;
begin
    Result := s;
    Count  := Len - Length( Result );
    if( Count > 0 )then begin
        Result := Result + AnsiString( StringOfChar( Chr, Count ) );
    end;
end;{ Rightpad }

function StringToCharAnsi( const s:UnicodeString; Len:SMALLINT ):CHAR_ANSI;
var
    AnsiStr : AnsiString;
begin
    Finalize( Result );
    if( ( Length( s ) = 0 ) or ( Len = 0 ) )then begin
        Result.Value[ 0 ] := AnsiChar( #32 );
    end else begin
        AnsiStr := s;  //convert UTF16 -> ANSI
        AnsiStr := Rightpad( Copy( AnsiStr, 1, Len ), Len, AnsiChar( #32 ) );
        if( Length( AnsiStr ) > 0 )then begin
            Move( POINTER( AnsiStr )^, Result.Value, Length( AnsiStr ) );
        end;
    end;
end;{ StringToChar }

function CalcCharLength( s:Utf8String; LimitByteLen:LONGINT ):LONGINT;
var
    ByteLen : LONGINT;
    Bytes : TBytes;
begin
    Result := 0;
    System.Finalize( bytes );
    if( ( Length( s ) > 0 ) and ( LimitByteLen > 0 ) )then begin
        ByteLen := TEncoding.UTF8.GetByteCount( s );
        SetLength( Bytes, ByteLen );
        Move( POINTER( s )^, POINTER( Bytes )^, ByteLen );
        if( ByteLen <= LimitByteLen )then begin
            Result := Length( s );
        end else begin
            Result := TEncoding.UTF8.GetCharCount( Bytes, 0, LimitByteLen );
        end;
    end;
end;{ CalcCharLength }

function Truncate( s:Utf8String; LimitByteLen:LONGINT ):Utf8String;
var
    LimitCharLen : LONGINT;
begin
    System.Finalize( Result );
    if( ( Length( s ) > 0 ) and ( LimitByteLen > 0 ) )then begin
        LimitCharLen := CalcCharLength( s, LimitByteLen );
        SetLength( s, LimitCharLen );
        Result := s;
    end;
end;{ Truncate }

function StringToCharUtf8( const s:UnicodeString; Len:SMALLINT ):CHAR_UTF8;
var
    TailLen : LONGINT;
    Utf8Str, Tail : Utf8String;
begin
    System.Finalize( Result );
    System.Finalize( Utf8Str );
    if( ( Length( s ) = 0 ) or ( Len = 0 ) )then begin
        Result.Value[ 0 ] := #32;
    end else begin
        Utf8Str := s;
        if( Len  > SizeOf( Result ) )then begin
            Len := SizeOf( Result );
        end;
        Utf8Str := Truncate( Utf8Str, Len );
        TailLen := Len - TEncoding.UTF8.GetByteCount( Utf8Str );
        if( TailLen > 0 )then begin
            Tail    := Utf8String( StringOfChar( #32, TailLen ) );
            Utf8Str := Utf8Str + Tail;
        end;
        if( Length( Utf8Str ) > 0 )then begin
            Move( POINTER( Utf8Str )^, Result.Value, TEncoding.UTF8.GetByteCount( Utf8Str ) );
        end;
    end;
end;{ StringToCharUtf8 }

function VarcharToString( const v:VARCHAR_ANSI ):UnicodeString; overload;
var
    AnsiStr : AnsiString;
begin
    System.Finalize( Result );
    System.Finalize( AnsiStr );
    if( v.Length > 0 )then begin
        SetLength( AnsiStr, v.Length );
        Move( v.Value, POINTER( AnsiStr )^, v.Length );
        Result := AnsiStr; //converts UTF8 -> ANSI
    end;
end;{ VarcharToString }

function VarcharToString( const v:VARCHAR_UTF8 ):UnicodeString; overload;
var
    v_buff  : VARCHAR_UTF8;
    bytes   : TBytes;
    byteLen : LONGINT;
    Utf8Str : Utf8String;
begin
    System.Finalize( Result );
    System.Finalize( Utf8Str );
    Finalize( v_buff );
    if( v.Length > 0 )then begin
        Finalize( v_buff );
        Move( v, v_buff, SizeOf( v.Length ) + v.Length );
        byteLen := StrLen( PAnsiChar( @v_buff.Value ) );
        SetLength( bytes, byteLen );
        Move( v_buff.Value, POINTER( bytes )^, byteLen );
        Utf8Str := TEncoding.UTF8.GetString( bytes );
        Result  := Utf8Str; //converts UTF8 -> UTF16
    end;
end;{ VarcharToString }

function StringToVarcharAnsi( const s:UnicodeString; MaxLength:LONGINT = 32765 ):VARCHAR_ANSI;
var
    AnsiStr : AnsiString;
begin
    Finalize( Result );
    if( Length( s ) > 0 )then begin
        AnsiStr := s;  //convert UTF16 -> ANSI
        Result.Length := Length( AnsiStr );
        if( Result.Length > MaxLength )then begin
            Result.Length := MaxLength;
        end;
        Move( POINTER( AnsiStr )^, Result.Value, Result.Length );
    end;
end;{ StringToVarchar }

function StringToVarcharUtf8( const s:UnicodeString; MaxLength:LONGINT =  8191 ):VARCHAR_UTF8;
var
    Utf8Str : Utf8String;
begin
    System.Finalize( Result );
    System.Finalize( Utf8Str );
    if( Length( s ) > 0 )then begin
        Utf8Str := s;  //convert UTF16 -> UTF8
        if( Length( Utf8Str ) > MaxLength )then begin
            SetLength( Utf8Str, MaxLength );
        end;
        Result.Length := Length( Utf8Str );
        Move( POINTER( Utf8Str )^, Result.Value, TEncoding.UTF8.GetByteCount( Utf8Str ) );
    end;
end;{ StringToVarchar }

function ReadBlobBytes( Status:IStatus; Blob:IBlob ):TBytes;
const
    BlobChunkSize = $08000; //max possible value
    RsltChunkSize = $10000;
var
    SegmentLength, BlobSize : UINT32;
    pTarget : PBYTE;
begin
    System.Finalize( Result );
    if( ( Status <> nil ) and ( Blob <> nil ) )then begin
        BlobSize := 0;
        while( TRUE )do begin

            while( Length( Result ) < BlobSize + BlobChunkSize )do begin
                SetLength( Result, Length( Result ) + RsltChunkSize );
            end;
            pTarget := PBYTE( POINTER( Result ) ) + BlobSize;

            case Blob.getSegment( Status, BlobChunkSize, pTarget, @SegmentLength ) of
                IStatus.RESULT_OK,
                IStatus.RESULT_SEGMENT : begin
                    Inc( BlobSize, SegmentLength );
                end;
                else begin
                    break;
                end;
            end;

        end;
        SetLength( Result, BlobSize );
    end;
end;{ ReadBlobBytes }

function ReadBlobBytes( Status:IStatus; Context:IExternalContext; BlobId:ISC_QUAD ):TBytes;
var
    Attachment  : IAttachment;
    Transaction : ITransaction;
    Blob : IBlob;
begin
    System.Finalize( Result );
    if( ( Status <> nil ) and ( Context <> nil ) )then begin
        try
            Attachment  := nil;
            Transaction := nil;
            Blob        := nil;
            Attachment  := Context.getAttachment(  Status );
            if( Attachment <> nil )then begin
                Transaction := Context.getTransaction( Status );
                if( Transaction <> nil )then begin
                    Blob := Attachment.openBlob( Status, Transaction, @BlobId, 0, nil );
                    if( Blob <> nil )then begin
                        Result := ReadBlobBytes( Status, Blob );
                    end;
                end;
            end;
        finally
            if( Blob <> nil )then begin
                Blob.close( Status );
                Blob.release;
                Blob := nil;
            end;
            if( Transaction <> nil )then begin
                Transaction.release;
                Transaction := nil;
            end;
            if( Attachment <> nil )then begin
                Attachment.release;
                Attachment  := nil;
            end;
        end;

    end;
end;{ ReadBlobBytes }

function WriteBlobBytes( Status:IStatus; Blob:IBlob; pBytes:PBYTE; bLength:LONGINT ):BOOLEAN;
const
    BlobChunkSize = $08000; //max possible value
var
    BufLen : UINT32;
begin
    Result := FALSE;
    if( ( Status <> nil ) and ( Blob <> nil ) )then begin
        while( ( bLength > 0 ) and ( pBytes <> nil ) )do begin
            BufLen := BlobChunkSize;
            if( BufLen  > bLength )then begin
                BufLen := bLength;
            end;

            Blob.putSegment( Status, BufLen, pBytes );

            Inc( pBytes,  BufLen );
            Dec( bLength, BufLen );
        end;
        Result := TRUE;
    end;
end;{ WriteBlobBytes }

function WriteBlobBytes( Status:IStatus; Context:IExternalContext; pBlobId:ISC_QUADPtr; pBytes:PBYTE; bLength:LONGINT ):BOOLEAN;
var
    Attachment  : IAttachment;
    Transaction : ITransaction;
    Blob : IBlob;
begin
    Result := FALSE;
    if( ( Status <> nil ) and ( Context <> nil ) )then begin
        try
            Attachment  := nil;
            Transaction := nil;
            Blob        := nil;
            Attachment  := Context.getAttachment( Status );
            if( Attachment <> nil )then begin
                Transaction := Context.getTransaction( Status );
                if( Transaction <> nil )then begin
                    Blob := Attachment.createBlob( Status, Transaction, pBlobId, 0, nil );
                    if( Blob <> nil )then begin
                        Result := WriteBlobBytes( Status, Blob, pBytes, bLength );
                    end;
                end;
            end;
        finally
            if( Blob <> nil )then begin
                Blob.close( Status );
                Blob.release;
                Blob := nil;
            end;
            if( Transaction <> nil )then begin
                Transaction.release;
                Transaction := nil;
            end;
            if( Attachment <> nil )then begin
                Attachment.release;
                Attachment  := nil;
            end;
        end;

    end;
end;{ WriteBlobBytes }

{ TRoutineContext}

constructor TRoutineContext.Create( RoutineMetadata:IRoutineMetadata; Status:IStatus; Context:IExternalContext; InputMessage:PAnsiChar; OutputMessage:PAnsiChar );
begin
    fRoutineMetadata := RoutineMetadata;
    fStatus          := Status;
    fContext         := Context;
    fInputMessage    := InputMessage;
    fOutputMessage   := OutputMessage
end;{ TRoutineContext.Create }

function TRoutineContext.GetFieldMetadata( Status:IStatus; MessageType:TMessageType; FieldIndex:UINT32; out FieldMetadata:TFieldMetadata ):BOOLEAN;
var
    MessageMetadata : IMessageMetadata;
begin
    Result := FALSE;
    Finalize( FieldMetadata );
    if( fRoutineMetadata <> nil )then begin
        try
            MessageMetadata := nil;
            case MessageType of
                INPUT_MESSAGE  : MessageMetadata := fRoutineMetadata.getInputMetadata(  Status );
                OUTPUT_MESSAGE : MessageMetadata := fRoutineMetadata.getOutputMetadata( Status );
            end;
            if( MessageMetadata <> nil )then begin
                if( FieldIndex < MessageMetadata.getCount( Status ) )then begin
                    FieldMetadata.FieldIndex := FieldIndex;
                    FieldMetadata.FieldType  := MessageMetadata.getType(       Status, FieldIndex );
                    FieldMetadata.SubType    := MessageMetadata.getSubType(    Status, FieldIndex );
                    FieldMetadata.Length     := MessageMetadata.getLength(     Status, FieldIndex );
                    FieldMetadata.CharSet    := MessageMetadata.getCharSet(    Status, FieldIndex );
                    FieldMetadata.Offset     := MessageMetadata.getOffset(     Status, FieldIndex );
                    FieldMetadata.NullOffset := MessageMetadata.getNullOffset( Status, FieldIndex );
                    Result := TRUE;
                end;
            end;
        finally
            MessageMetadata.release;
            MessageMetadata := nil;
        end;

    end;
end;{ TRoutineContext.GetFieldMetadata }

function TRoutineContext.ReadInputOrdinal( Status:IStatus; FieldIndex:UINT32; out Value:INT64; out IsNull:WORDBOOL ):BOOLEAN;
var
    FieldMetadata : TFieldMetadata;
    pFieldData    : PAnsiChar;
begin
    Result := FALSE;
    Value  := 0;
    IsNull := TRUE;
    if( GetFieldMetadata( Status, INPUT_MESSAGE, FieldIndex, FieldMetadata ) )then begin
        IsNull := PWORDBOOL( pInputMessage + FieldMetadata.NullOffset )^;
        if( not IsNull )then begin
            pFieldData := pInputMessage + FieldMetadata.Offset;
            case FieldMetadata.Length of
                1 : Value := PSHORTINT( pFieldData )^;
                2 : Value := PSMALLINT( pFieldData )^;
                4 : Value := PLONGINT(  pFieldData )^;
                8 : Value := PINT64(    pFieldData )^;
            end;
        end;
        Result := TRUE;
    end;
end;{ TRoutineContext.ReadInputOrdinal }

function TRoutineContext.ReadInputShortint( Status:IStatus; FieldIndex:UINT32; out Value:SMALLINT; out IsNull:WORDBOOL ):BOOLEAN;
var
    vINT64 : INT64;
begin
    Result := FALSE;
    Value  := 0;
    IsNull := TRUE;
    if( ReadInputOrdinal( Status, FieldIndex, vINT64, IsNull ) )then begin
        if( not IsNull )then begin
            Value := SHORTINT( vINT64 );
        end;
        Result := TRUE;
    end;
end;{ TRoutineContext.ReadInputShortint }

function TRoutineContext.ReadInputSmallint( Status:IStatus; FieldIndex:UINT32; out Value:SMALLINT; out IsNull:WORDBOOL ):BOOLEAN;
var
    vINT64 : INT64;
begin
    Result := FALSE;
    Value  := 0;
    IsNull := TRUE;
    if( ReadInputOrdinal( Status, FieldIndex, vINT64, IsNull ) )then begin
        if( not IsNull )then begin
            Value := SMALLINT( vINT64 );
        end;
        Result := TRUE;
    end;
end;{ TRoutineContext.ReadInputSmallint }

function TRoutineContext.ReadInputLongint( Status:IStatus; FieldIndex:UINT32; out Value:LONGINT; out IsNull:WORDBOOL ):BOOLEAN;
var
    vINT64 : INT64;
begin
    Result := FALSE;
    Value  := 0;
    IsNull := TRUE;
    if( ReadInputOrdinal( Status, FieldIndex, vINT64, IsNull ) )then begin
        if( not IsNull )then begin
            Value := LONGINT( vINT64 );
        end;
        Result := TRUE;
    end;
end;{ TRoutineContext.ReadInputLongint }

function TRoutineContext.ReadInputBigint( Status:IStatus; FieldIndex:UINT32; out Value:INT64; out IsNull:WORDBOOL ):BOOLEAN;
begin
    Result := ReadInputOrdinal( Status, FieldIndex, Value, IsNull );
end;{ TRoutineContext.ReadInputBigint }

function TRoutineContext.ReadInputString( Status:IStatus; FieldIndex:UINT32; out Value:UnicodeString; out IsNull:WORDBOOL ):BOOLEAN;
var
    FieldMetadata : TFieldMetadata;
    pFieldData    : PAnsiChar;
    BlobId : ISC_QUAD;
    Bytes  : TBytes;
begin
    Result := FALSE;
    System.Finalize( Value );
    IsNull := TRUE;
    if( GetFieldMetadata( Status, INPUT_MESSAGE, FieldIndex, FieldMetadata ) )then begin
        IsNull := PWORDBOOL( pInputMessage + FieldMetadata.NullOffset )^;
        if( not IsNull )then begin
            pFieldData := pInputMessage + FieldMetadata.Offset;
            case FieldMetadata.FieldType of
                FB_CHAR : begin
                    case FieldMetadata.CharSet of
                        FB_CHARSET_WIN1251 : Value := CharToString( PCHAR_ANSI( pFieldData )^, FieldMetadata.Length );
                        FB_CHARSET_UTF8    : Value := CharToString( PCHAR_UTF8( pFieldData )^, FieldMetadata.Length );
                    end;
                end;
                FB_VARCHAR : begin
                    case FieldMetadata.CharSet of
                        FB_CHARSET_WIN1251 : Value := VarcharToString( PVARCHAR_ANSI( pFieldData )^ );
                        FB_CHARSET_UTF8    : Value := VarcharToString( PVARCHAR_UTF8( pFieldData )^ );
                    end;
                end;
                FB_BLOB : begin
                    System.Finalize( Bytes );
                    if( FieldMetadata.SubType = FB_SUBTYPE_TEXT )then begin
                        BlobId := ISC_QUADPtr( pFieldData )^;
                        Bytes  := ReadBlobBytes( Status, Context, BlobId );
                        case FieldMetadata.CharSet of
                            FB_CHARSET_WIN1251 : Value := TEncoding.ANSI.GetString( Bytes );
                            FB_CHARSET_UTF8    : Value := TEncoding.UTF8.GetString( Bytes );
                        end;
                    end;
                end;
            end;
        end;
        Result := TRUE;
    end;
end;{ TRoutineContext.ReadInputString }

function TRoutineContext.ReadInputBlob( Status:IStatus; FieldIndex:UINT32; out Value:TBytes; out IsNull:WORDBOOL ):BOOLEAN;
var
    FieldMetadata : TFieldMetadata;
    pFieldData    : PAnsiChar;
    BlobId        : ISC_QUAD;
begin
    Result := FALSE;
    System.Finalize( Value );
    Finalize( BlobId );
    IsNull := TRUE;
    if( GetFieldMetadata( Status, INPUT_MESSAGE, FieldIndex, FieldMetadata ) )then begin
        IsNull := PWORDBOOL( pInputMessage + FieldMetadata.NullOffset )^;
        if( not IsNull )then begin
            pFieldData := pInputMessage + FieldMetadata.Offset;
            BlobId     := ISC_QUADPtr( pFieldData )^;
            Value      := ReadBlobBytes( Status, Context, BlobId );
        end;
        Result := TRUE;
    end;
end;{ TRoutineContext.ReadInputBlob }

function TRoutineContext.WriteOutputOrdinal( Status:IStatus; FieldIndex:UINT32; Value:INT64; IsNull:WORDBOOL ):BOOLEAN;
var
    FieldMetadata : TFieldMetadata;
    pFieldData    : PAnsiChar;
begin
    Result := FALSE;
    if( GetFieldMetadata( Status, OUTPUT_MESSAGE, FieldIndex, FieldMetadata ) )then begin
        PWORDBOOL( pOutputMessage + FieldMetadata.NullOffset )^ := IsNull;
        if( IsNull )then begin
            Value := 0;
        end;
        pFieldData := pOutputMessage + FieldMetadata.Offset;
        case FieldMetadata.Length of
            1 : PSHORTINT( pFieldData )^ := SHORTINT( Value );
            2 : PSMALLINT( pFieldData )^ := SMALLINT( Value );
            4 : PLONGINT(  pFieldData )^ := LONGINT(  Value );
            8 : PINT64(    pFieldData )^ := Value;
        end;
        Result := TRUE;
    end;

end;{ TRoutineContext.WriteOutputOrdinal }

function TRoutineContext.WriteOutputShortint( Status:IStatus; FieldIndex:UINT32; Value:SMALLINT; IsNull:WORDBOOL ):BOOLEAN;
begin
    Result := WriteOutputOrdinal( Status, FieldIndex, INT64( Value ), IsNull );
end;{ TRoutineContext.WriteOutputShortint }

function TRoutineContext.WriteOutputSmallint( Status:IStatus; FieldIndex:UINT32; Value:SMALLINT; IsNull:WORDBOOL ):BOOLEAN;
begin
    Result := WriteOutputOrdinal( Status, FieldIndex, INT64( Value ), IsNull );
end;{ TRoutineContext.WriteOutputSmallint }

function TRoutineContext.WriteOutputLongint( Status:IStatus; FieldIndex:UINT32; Value:LONGINT; IsNull:WORDBOOL ):BOOLEAN;
begin
    Result := WriteOutputOrdinal( Status, FieldIndex, INT64( Value ), IsNull );
end;{ TRoutineContext.WriteOutputLongint }

function TRoutineContext.WriteOutputBigint( Status:IStatus; FieldIndex:UINT32; Value:INT64; IsNull:WORDBOOL ):BOOLEAN;
begin
    Result := WriteOutputOrdinal( Status, FieldIndex, INT64( Value ), IsNull );
end;{ TRoutineContext.WriteOutputBigint }

function TRoutineContext.WriteOutputString( Status:IStatus; FieldIndex:UINT32; Value:UnicodeString; IsNull:WORDBOOL ):BOOLEAN;
var
    FieldMetadata : TFieldMetadata;
    pFieldData    : PAnsiChar;
    c_ansi : CHAR_ANSI;
    c_utf8 : CHAR_UTF8;
    v_ansi : VARCHAR_ANSI;
    v_utf8 : VARCHAR_UTF8;
    pBlobId   : ISC_QUADPtr;
    AnsiValue : AnsiString;
    Utf8Value : Utf8String;
begin
    Result := FALSE;
    if( GetFieldMetadata( Status, OUTPUT_MESSAGE, FieldIndex, FieldMetadata ) )then begin
        PWORDBOOL( pOutputMessage + FieldMetadata.NullOffset )^ := IsNull;
        if( not IsNull )then begin
            pFieldData := pOutputMessage + FieldMetadata.Offset;
            case FieldMetadata.FieldType of
                FB_CHAR : begin
                    case FieldMetadata.CharSet of
                        FB_CHARSET_WIN1251 : begin
                            c_ansi := StringToCharAnsi( Value, FieldMetadata.Length );
                            Move( c_ansi.Value, pFieldData^, FieldMetadata.Length );
                        end;
                        FB_CHARSET_UTF8    : begin
                            c_utf8 := StringToCharUtf8( Value, FieldMetadata.Length );
                            Move( c_utf8.Value, pFieldData^, FieldMetadata.Length );
                        end;
                    end;
                end;
                FB_VARCHAR : begin
                    FillChar( pFieldData^, FieldMetadata.Length, 0 );
                    case FieldMetadata.CharSet of
                        FB_CHARSET_WIN1251 : begin
                            v_ansi := StringToVarcharAnsi( Value, FieldMetadata.Length - SizeOf( SMALLINT ) );
                            Move( v_ansi, pFieldData^, SizeOf( v_ansi.Length ) + v_ansi.Length );
                        end;
                        FB_CHARSET_UTF8 : begin
                            v_utf8 := StringToVarcharUtf8( Value, FieldMetadata.Length - SizeOf( SMALLINT ) );
                            Move( v_utf8, pFieldData^, SizeOf( v_utf8.Length ) + v_utf8.Length );
                        end;
                    end;
                end;
                FB_BLOB : begin
                    if( FieldMetadata.SubType = FB_SUBTYPE_TEXT )then begin
                        pBlobId := ISC_QUADPtr( pOutputMessage + FieldMetadata.Offset );
                        case FieldMetadata.CharSet of
                            FB_CHARSET_WIN1251 : begin
                                AnsiValue := AnsiString( Value );
                                WriteBlobBytes( Status, Context, pBlobId, POINTER( AnsiValue ), Length( AnsiValue ) );
                            end;
                            FB_CHARSET_UTF8 : begin
                                Utf8Value := Utf8String( Value );
                                WriteBlobBytes( Status, Context, pBlobId, POINTER( Utf8Value ), TEncoding.UTF8.GetByteCount( Utf8Value ) );
                            end;
                        end;
                    end;
                end;
            end;
        end;
        Result := TRUE;
    end;
end;{ TRoutineContext.WriteOutputString }

function TRoutineContext.WriteOutputBlob( Status:IStatus; FieldIndex:UINT32; Value:TBytes; IsNull:WORDBOOL ):BOOLEAN;
var
    FieldMetadata : TFieldMetadata;
    pBlobId       : ISC_QUADPtr;
begin
    Result := FALSE;
    System.Finalize( Value );
    IsNull := TRUE;
    if( GetFieldMetadata( Status, OUTPUT_MESSAGE, FieldIndex, FieldMetadata ) )then begin
        PWORDBOOL( pOutputMessage + FieldMetadata.NullOffset )^ := IsNull;
        if( ( not IsNull ) )then begin
            pBlobId := ISC_QUADPtr( pInputMessage + FieldMetadata.Offset );
            Result  := WriteBlobBytes( Status, Context, pBlobId, POINTER( Value ), Length( Value ) );
        end;
    end;
end;{ TRoutineContext.WriteOutputBlob }


{ TBwrProcedureFactory }

procedure TBwrProcedureFactory.dispose;
begin
    Destroy;
end;{ TBwrProcedureFactory.dispose }

function TBwrProcedureFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalProcedure;
begin
    Result := TBwrProcedure.create( AMetadata );
end;{ TBwrProcedureFactory.newItem }

procedure TBwrProcedureFactory.setup( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata; AInBuilder:IMetadataBuilder; AOutBuilder:IMetadataBuilder );
begin
end;{ TBwrProcedureFactory.setup }

{ TBwrProcedure }

constructor TBwrProcedure.Create( RoutineMetadata:IRoutineMetadata );
begin
    inherited Create;
    fRoutineMetadata := RoutineMetadata;
end;{ TBwrProcedure.Create }

destructor TBwrProcedure.Destroy;
begin
    if( fRoutineContext <> nil )then begin
        fRoutineContext.Free;
        fRoutineContext := nil;
    end;
    inherited Destroy;
end;{ TBwrProcedure.Destroy }

procedure TBwrProcedure.dispose;
begin
    Destroy;
end;{ TBwrProcedure.dispose }

procedure TBwrProcedure.getCharSet( AStatus:IStatus; AContext:IExternalContext; AName:PAnsiChar; ANameSize:UINT32 );
begin
end;{ TBwrProcedure.getCharSet }

function TBwrProcedure.open( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER ):IExternalResultSet;
begin
    fRoutineContext := TRoutineContext.Create(
        fRoutineMetadata
      , AStatus
      , AContext
      , aInMsg
      , aOutMsg
    );
end;{ TBwrProcedure.open }

{ TBwrSelectiveProcedure }

function TBwrSelectiveProcedure.open( AStatus:IStatus; AContext:IExternalContext; AInMsg:POINTER; AOutMsg:POINTER ):IExternalResultSet;
begin
    inherited open( AStatus, AContext, aInMsg, aOutMsg );
    Result := TBwrResultSet.Create( Self, AStatus );
end;{ TBwrSelectiveProcedure.open }

{ TBwrResultSet }

constructor TBwrResultSet.Create( ASelectiveProcedure:TBwrSelectiveProcedure; AStatus:IStatus );
begin
    inherited Create;
    fSelectiveProcedure := ASelectiveProcedure;
end;{ TBwrResultSet.Create }

procedure TBwrResultSet.dispose();
begin
    Destroy;
end;{ TBwrResultSet.dispose }

function TBwrResultSet.GetRoutineContext():TRoutineContext;
begin
    Result := nil;
    if( fSelectiveProcedure <> nil )then begin
        Result := fSelectiveProcedure.RoutineContext;
    end;
end;{ TBwrResultSet.GetRoutineContext }

function TBwrResultSet.fetch( AStatus:IStatus ):BOOLEAN;
begin
    Result := FALSE;
end;{ TBwrResultSet.fetch }


{ TBwrFunctionFactory }

procedure TBwrFunctionFactory.dispose;
begin
    Destroy;
end;{ TBwrFunctionFactory.dispose }

function TBwrFunctionFactory.newItem( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata ):IExternalFunction;
begin
    Result := TBwrFunction.create( AMetadata );
end;{ TBwrFunctionFactory.newItem }

procedure TBwrFunctionFactory.setup( AStatus:IStatus; AContext:IExternalContext; AMetadata:IRoutineMetadata; AInBuilder:IMetadataBuilder; AOutBuilder:IMetadataBuilder );
begin
    AStatus := AStatus;
end;{ TBwrFunctionFactory.setup }

{ TBwrFunction }

constructor TBwrFunction.Create( RoutineMetadata:IRoutineMetadata );
begin
    inherited Create;
    fRoutineMetadata := RoutineMetadata;
end;{ TBwrProcedure.Create }

destructor TBwrFunction.Destroy;
begin
    if( fRoutineContext <> nil )then begin
        fRoutineContext.Free;
        fRoutineContext := nil;
    end;
    inherited Destroy;
end;{ TBwrFunction.Destroy }

procedure TBwrFunction.dispose;
begin
    Destroy;
end;{ TBwrFunction.dispose }

procedure TBwrFunction.getCharSet( AStatus:IStatus; AContext:IExternalContext; AName:PAnsiChar; ANameSize:UINT32 );
begin
end;{ TBwrFunction.getCharSet }

procedure TBwrFunction.execute( AStatus:IStatus; AContext:IExternalContext; aInMsg:POINTER; aOutMsg:POINTER );
begin
    fRoutineContext := TRoutineContext.Create(
        fRoutineMetadata
      , AStatus
      , AContext
      , aInMsg
      , aOutMsg
    );
end;{ TBwrFunction.execute }



end.
