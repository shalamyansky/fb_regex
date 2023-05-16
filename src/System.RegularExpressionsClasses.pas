{-----------------------?----------------------?---------------------------------}
// Very short version of System.Classes to use with RegularExpressions units.
// Using RegularExpressionsClasses instead of System.Classes prevents
// oleaut32.dll loading at runtime.
// Author: michel
// Date:   2023-05-16

unit System.RegularExpressionsClasses;

interface

uses
    System.Types
  , System.SysUtils
;

type

//TList
{$REGION TLIST_INTERFACE}
TNotifyEvent = procedure( Sender:TObject ) of object;

EListError = System.SysUtils.EListError;

PPointerList = ^TPointerList;
TPointerList = array of Pointer;
TListSortCompare = function (Item1, Item2: Pointer): Integer;
TListSortCompareFunc = reference to function (Item1, Item2: Pointer): Integer;
TListNotification = (lnAdded, lnExtracted, lnDeleted);

// these operators are used in Assign and go beyond simply copying
//   laCopy = dest becomes a copy of the source
//   laAnd  = intersection of the two lists
//   laOr   = union of the two lists
//   laXor  = only those not in both lists
// the last two operators can actually be thought of as binary operators but
// their implementation has been optimized over their binary equivalent.
//   laSrcUnique  = only those unique to source (same as laAnd followed by laXor)
//   laDestUnique = only those unique to dest   (same as laOr followed by laXor)
TListAssignOp = (laCopy, laAnd, laOr, laXor, laSrcUnique, laDestUnique);

TList = class;

TListEnumerator = class
  private
    FIndex: Integer;
    FList: TList;
  public
    constructor Create(AList: TList);
    function GetCurrent: Pointer; inline;
    function MoveNext: Boolean;
    property Current: Pointer read GetCurrent;
end;

TList = class(TObject)
  private
    FList: TPointerList;
    FCount: Integer;
    FCapacity: Integer;
  protected
    function Get(Index: Integer): Pointer;
    procedure Grow; virtual;
    procedure Put(Index: Integer; Item: Pointer);
    procedure Notify(Ptr: Pointer; Action: TListNotification); virtual;
    procedure SetCapacity(NewCapacity: Integer);
    procedure SetCount(NewCount: Integer);
  public
    type
      TDirection = System.Types.TDirection;

    destructor Destroy; override;
    function Add(Item: Pointer): Integer;
    procedure Clear; virtual;
    procedure Delete(Index: Integer);
    class procedure Error(const Msg: string; Data: NativeInt); overload; virtual;
    class procedure Error(Msg: PResStringRec; Data: NativeInt); overload;
    procedure Exchange(Index1, Index2: Integer);
    function Expand: TList;
    function Extract(Item: Pointer): Pointer; inline;
    function ExtractItem(Item: Pointer; Direction: TDirection): Pointer;
    function First: Pointer; inline;
    function GetEnumerator: TListEnumerator;
    function IndexOf(Item: Pointer): Integer;
    function IndexOfItem(Item: Pointer; Direction: TDirection): Integer;
    procedure Insert(Index: Integer; Item: Pointer);
    function Last: Pointer;
    procedure Move(CurIndex, NewIndex: Integer);
    function Remove(Item: Pointer): Integer; inline;
    function RemoveItem(Item: Pointer; Direction: TDirection): Integer;
    procedure Pack;
    procedure Sort(Compare: TListSortCompare);
    procedure SortList(const Compare: TListSortCompareFunc);
    procedure Assign(ListA: TList; AOperator: TListAssignOp = laCopy; ListB: TList = nil);
    property Capacity: Integer read FCapacity write SetCapacity;
    property Count: Integer read FCount write SetCount;
    property Items[Index: Integer]: Pointer read Get write Put; default;
    property List: TPointerList read FList;
end;
{$ENDREGION TLIST_INTERFACE}

//TStrings
{$REGION TSTRINGS_INTERFACE}
TStrings = class( TObject )
  private
    fArray : TArray<UnicodeString>;
  public
    constructor Create;
    destructor Destroy; override;
    function Add( const S:UnicodeString ):INT32; virtual;
    function ToStringArray:TArray<UnicodeString>;
end;{ TStrings }

TStringList = class( TStrings )
end;{ TStringList }
{$ENDREGION TSTRINGS_INTERFACE}


implementation

uses
  System.RTLConsts
;

//TList
{$REGION TLIST_IMPLEMENTATION}

{ TListEnumerator }

constructor TListEnumerator.Create(AList: TList);
begin
  inherited Create;
  FIndex := -1;
  FList := AList;
end;

function TListEnumerator.GetCurrent: Pointer;
begin
  Result := FList[FIndex];
end;

function TListEnumerator.MoveNext: Boolean;
begin
  Result := FIndex < FList.Count - 1;
  if Result then
    Inc(FIndex);
end;

{ TList }

destructor TList.Destroy;
begin
  Clear;
end;

function TList.Add(Item: Pointer): Integer;
begin
  Result := FCount;
  if Result = FCapacity then
    Grow;
  FList[Result] := Item;
  Inc(FCount);
  if (Item <> nil) and (ClassType <> TList) then
    Notify(Item, lnAdded);
end;

procedure TList.Clear;
begin
  SetCount(0);
  SetCapacity(0);
end;

procedure TList.Delete(Index: Integer);
var
  Temp: Pointer;
begin
  if (Index < 0) or (Index >= FCount) then
    Error(@SListIndexError, Index);
  Temp := FList[Index];
  Dec(FCount);
  if Index < FCount then
    System.Move(FList[Index + 1], FList[Index],
      (FCount - Index) * SizeOf(Pointer));
  if (Temp <> nil) and (ClassType <> TList) then
    Notify(Temp, lnDeleted);
end;

class procedure TList.Error(const Msg: string; Data: NativeInt);
begin
  raise EListError.CreateFmt(Msg, [Data]) at ReturnAddress;
end;

class procedure TList.Error(Msg: PResStringRec; Data: NativeInt);
begin
  raise EListError.CreateFmt(LoadResString(Msg), [Data]) at ReturnAddress;
end;

procedure TList.Exchange(Index1, Index2: Integer);
var
  Item: Pointer;
begin
  if (Index1 < 0) or (Index1 >= FCount) then
    Error(@SListIndexError, Index1);
  if (Index2 < 0) or (Index2 >= FCount) then
    Error(@SListIndexError, Index2);
  Item := FList[Index1];
  FList[Index1] := FList[Index2];
  FList[Index2] := Item;
end;

function TList.Expand: TList;
begin
  if FCount = FCapacity then
    Grow;
  Result := Self;
end;

function TList.First: Pointer;
begin
  Result := Get(0);
end;

function TList.Get(Index: Integer): Pointer;
begin
  if Cardinal(Index) >= Cardinal(FCount) then
    Error(@SListIndexError, Index);
  Result := FList[Index];
end;

function TList.GetEnumerator: TListEnumerator;
begin
  Result := TListEnumerator.Create(Self);
end;

procedure TList.Grow;
var
  Delta: Integer;
begin
  if FCapacity > 64 then
    Delta := FCapacity div 4
  else
    if FCapacity > 8 then
      Delta := 16
    else
      Delta := 4;
  SetCapacity(FCapacity + Delta);
end;

function TList.IndexOf(Item: Pointer): Integer;
var
  P: PPointer;
begin
  P := Pointer(FList);
  for Result := 0 to FCount - 1 do
  begin
    if P^ = Item then
      Exit;
    Inc(P);
  end;
  Result := -1;
end;

function TList.IndexOfItem(Item: Pointer; Direction: TDirection): Integer;
var
  P: PPointer;
begin
  if Direction = FromBeginning then
    Result := IndexOf(Item)
  else
  begin
    if FCount > 0 then
    begin
      P := Pointer(@List[FCount - 1]);
      for Result := FCount - 1 downto 0 do
      begin
        if P^ = Item then
          Exit;
        Dec(P);
      end;
    end;
    Result := -1;
  end;
end;

procedure TList.Insert(Index: Integer; Item: Pointer);
begin
  if (Index < 0) or (Index > FCount) then
    Error(@SListIndexError, Index);
  if FCount = FCapacity then
    Grow;
  if Index < FCount then
    System.Move(FList[Index], FList[Index + 1],
      (FCount - Index) * SizeOf(Pointer));
  FList[Index] := Item;
  Inc(FCount);
  if (Item <> nil) and (ClassType <> TList) then
    Notify(Item, lnAdded);
end;

function TList.Last: Pointer;
begin
  if FCount > 0 then
    Result := FList[Count - 1]
  else
  begin
    Error(@SListIndexError, 0);
    Result := nil;
  end;
end;

procedure TList.Move(CurIndex, NewIndex: Integer);
var
  Item: Pointer;
begin
  if CurIndex <> NewIndex then
  begin
    if (NewIndex < 0) or (NewIndex >= FCount) then
      Error(@SListIndexError, NewIndex);
    Item := Get(CurIndex);
    FList[CurIndex] := nil;
    Delete(CurIndex);
    Insert(NewIndex, nil);
    FList[NewIndex] := Item;
  end;
end;

procedure TList.Put(Index: Integer; Item: Pointer);
var
  Temp: Pointer;
begin
  if (Index < 0) or (Index >= FCount) then
    Error(@SListIndexError, Index);
  if Item <> FList[Index] then
  begin
    Temp := FList[Index];
    FList[Index] := Item;
    if ClassType <> TList then
    begin
      if Temp <> nil then
        Notify(Temp, lnDeleted);
      if Item <> nil then
        Notify(Item, lnAdded);
    end;
  end;
end;

function TList.Remove(Item: Pointer): Integer;
begin
  Result := RemoveItem(Item, TList.TDirection.FromBeginning);
end;

function TList.RemoveItem(Item: Pointer; Direction: TDirection): Integer;
begin
  Result := IndexOfItem(Item, Direction);
  if Result >= 0 then
    Delete(Result);
end;

procedure TList.Pack;
var
  PackedCount : Integer;
  StartIndex : Integer;
  EndIndex : Integer;
begin
  if FCount = 0 then
    Exit;

  PackedCount := 0;
  StartIndex := 0;
  repeat
    // Locate the first/next non-nil element in the list
    while (StartIndex < FCount) and (FList[StartIndex] = nil) do
      Inc(StartIndex);

    if StartIndex < FCount then // There is nothing more to do
    begin
      // Locate the next nil pointer
      EndIndex := StartIndex;
      while (EndIndex < FCount) and (FList[EndIndex] <> nil) do
        Inc(EndIndex);
      Dec(EndIndex);

      // Move this block of non-null items to the index recorded in PackedToCount:
      // If this is a contiguous non-nil block at the start of the list then
      // StartIndex and PackedToCount will be equal (and 0) so don't bother with the move.
      if StartIndex > PackedCount then
        System.Move(FList[StartIndex],
                    FList[PackedCount],
                    (EndIndex - StartIndex + 1) * SizeOf(Pointer));

      // Set the PackedToCount to reflect the number of items in the list
      // that have now been packed.
      Inc(PackedCount, EndIndex - StartIndex + 1);

      // Reset StartIndex to the element following EndIndex
      StartIndex := EndIndex + 1;
    end;
  until StartIndex >= FCount;

  // Set Count so that the 'free' item
  FCount := PackedCount;
end;

procedure TList.SetCapacity(NewCapacity: Integer);
begin
  if NewCapacity < FCount then
    Error(@SListCapacityError, NewCapacity);
  if NewCapacity <> FCapacity then
  begin
    SetLength(FList, NewCapacity);
    FCapacity := NewCapacity;
  end;
end;

procedure TList.SetCount(NewCount: Integer);
var
  I: Integer;
  Temp: Pointer;
begin
  if NewCount < 0 then
    Error(@SListCountError, NewCount);
  if NewCount <> FCount then
  begin
    if NewCount > FCapacity then
      SetCapacity(NewCount);
    if NewCount > FCount then
      FillChar(FList[FCount], (NewCount - FCount) * SizeOf(Pointer), 0)
    else
    if ClassType <> TList then
    begin
      for I := FCount - 1 downto NewCount do
      begin
        Dec(FCount);
        Temp := List[I];
        if Temp <> nil then
          Notify(Temp, lnDeleted);
      end;
    end;
    FCount := NewCount;
  end;
end;

procedure QuickSort(SortList: TPointerList; L, R: Integer;
  SCompare: TListSortCompareFunc);
var
  I, J: Integer;
  P, T: Pointer;
begin
  repeat
    I := L;
    J := R;
    P := SortList[(L + R) shr 1];
    repeat
      while SCompare(SortList[I], P) < 0 do
        Inc(I);
      while SCompare(SortList[J], P) > 0 do
        Dec(J);
      if I <= J then
      begin
        if I <> J then
        begin
          T := SortList[I];
          SortList[I] := SortList[J];
          SortList[J] := T;
        end;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then
      QuickSort(SortList, L, J, SCompare);
    L := I;
  until I >= R;
end;

procedure TList.Sort(Compare: TListSortCompare);
begin
  if Count > 1 then
    QuickSort(FList, 0, Count - 1,
      function(Item1, Item2: Pointer): Integer
      begin
        Result := Compare(Item1, Item2);
      end);
end;

procedure TList.SortList(const Compare: TListSortCompareFunc);
begin
  if Count > 1 then
    QuickSort(FList, 0, Count - 1, Compare);
end;

function TList.Extract(Item: Pointer): Pointer;
begin
  Result := ExtractItem(Item, TDirection.FromBeginning);
end;

function TList.ExtractItem(Item: Pointer; Direction: TDirection): Pointer;
var
  I: Integer;
begin
  Result := nil;
  I := IndexOfItem(Item, Direction);
  if I >= 0 then
  begin
    Result := Item;
    FList[I] := nil;
    Delete(I);
    if ClassType <> TList then
      Notify(Result, lnExtracted);
  end;
end;

procedure TList.Notify(Ptr: Pointer; Action: TListNotification);
begin
end;

procedure TList.Assign(ListA: TList; AOperator: TListAssignOp; ListB: TList);
var
  I: Integer;
  LTemp, LSource: TList;
begin
  // ListB given?
  if ListB <> nil then
  begin
    LSource := ListB;
    Assign(ListA);
  end
  else
    LSource := ListA;

  // on with the show
  case AOperator of

    // 12345, 346 = 346 : only those in the new list
    laCopy:
      begin
        Clear;
        Capacity := LSource.Capacity;
        for I := 0 to LSource.Count - 1 do
          Add(LSource[I]);
      end;

    // 12345, 346 = 34 : intersection of the two lists
    laAnd:
      for I := Count - 1 downto 0 do
        if LSource.IndexOf(Items[I]) = -1 then
          Delete(I);

    // 12345, 346 = 123456 : union of the two lists
    laOr:
      for I := 0 to LSource.Count - 1 do
        if IndexOf(LSource[I]) = -1 then
          Add(LSource[I]);

    // 12345, 346 = 1256 : only those not in both lists
    laXor:
      begin
        LTemp := TList.Create; // Temp holder of 4 byte values
        try
          LTemp.Capacity := LSource.Count;
          for I := 0 to LSource.Count - 1 do
            if IndexOf(LSource[I]) = -1 then
              LTemp.Add(LSource[I]);
          for I := Count - 1 downto 0 do
            if LSource.IndexOf(Items[I]) <> -1 then
              Delete(I);
          I := Count + LTemp.Count;
          if Capacity < I then
            Capacity := I;
          for I := 0 to LTemp.Count - 1 do
            Add(LTemp[I]);
        finally
          LTemp.Free;
        end;
      end;

    // 12345, 346 = 125 : only those unique to source
    laSrcUnique:
      for I := Count - 1 downto 0 do
        if LSource.IndexOf(Items[I]) <> -1 then
          Delete(I);

    // 12345, 346 = 6 : only those unique to dest
    laDestUnique:
      begin
        LTemp := TList.Create;
        try
          LTemp.Capacity := LSource.Count;
          for I := LSource.Count - 1 downto 0 do
            if IndexOf(LSource[I]) = -1 then
              LTemp.Add(LSource[I]);
          Assign(LTemp);
        finally
          LTemp.Free;
        end;
      end;
  end;
end;
{$ENDREGION TLIST_IMPLEMENTATION}

//TStrings
{$REGION TSTRINGS_IMPLEMENTATION}
constructor TStrings.Create;
begin
    inherited Create;
    Finalize( fArray );
end;{ TStrings.Create }

destructor TStrings.Destroy;
begin
    Finalize( fArray );
    inherited Destroy;
end;{ TStrings.Destroy }

function TStrings.Add( const S:UnicodeString ):INT32;
begin
    SetLength( fArray, Length( fArray ) + 1 );
    fArray[ Length( fArray ) - 1 ] := S;
end;{ TStrings.Add }

function TStrings.ToStringArray: TArray<UnicodeString>;
begin
    Result := fArray;
end;{ TStrings.ToStringArray }
{$ENDREGION TSTRINGS_IMPLEMENTATION}

end.
