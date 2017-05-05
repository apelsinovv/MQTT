unit IntfEx;

interface

uses SysUtils, Classes, SyncObjs;

type
  IWeakRef = interface
    procedure _Clean;
    function IsAlive: Boolean;
    function Get: IUnknown;
  end;

  IWeakly = interface
  ['{F1DFE67A-B796-4B95-ADE1-8AA030A7546D}']
    function WeakRef: IWeakRef;
  end;

  TWeaklyInterfacedObject = class(TInterfacedObject, IWeakly)
  private
    FWeakRef: IWeakRef;
  public
    function WeakRef: IWeakRef;
    destructor Destroy; override;
  end;

  IPublisher = interface
  ['{CDE9EE5C-021F-4942-A92A-39FC74395B4B}']
    procedure Subscribe  (const ASubscriber: IWeakly);
    procedure Unsubscribe(const ASubscriber: IWeakly);
  end;

  TWeakRefArr = array of IWeakRef;

  TBasePublisher = class(TInterfacedObject, IPublisher)
  private
    FCS   : TCriticalSection;
    FCount: Integer;
    FItems: TWeakRefArr;
    procedure Grow(const NeedCapacity: Integer);
    procedure Pack;
  protected
    procedure SafePack;
    function GetItems: TWeakRefArr;
  public
    procedure Subscribe  (const ASubscriber: IWeakly);
    procedure Unsubscribe(const ASubscriber: IWeakly);

    constructor Create(const AThreadSafe: Boolean);
    destructor Destroy; override;
  end;

  TAutoPublisher = packed record
    Publisher: IPublisher;
    class operator Add(const APublisher: TAutoPublisher; const ASubscriber: IWeakly): Boolean;
    class operator Subtract(const APublisher: TAutoPublisher; const ASubscriber: IWeakly): Boolean;
  end;

function IsAlive(const Ref: IWeakRef): Boolean;

implementation

type
  TWeakRef = class(TInterfacedObject, IWeakRef)
  private
    FOwner: Pointer;
  public
    procedure _Clean;
    function IsAlive: Boolean;
    function Get: IUnknown;
    constructor Create(const AOwner: IUnknown);
  end;

function IsAlive(const Ref: IWeakRef): Boolean;
begin
  Result := Assigned(Ref) and Ref.IsAlive;
end;

{ TWeaklyInterfacedObject }

destructor TWeaklyInterfacedObject.Destroy;
begin
  inherited;
  FWeakRef._Clean;
end;

function TWeaklyInterfacedObject.WeakRef: IWeakRef;
begin
  if FWeakRef = nil then FWeakRef := TWeakRef.Create(Self);
  Result := FWeakRef;
end;

{ TWeakRef }

constructor TWeakRef.Create(const AOwner: IInterface);
begin
  FOwner := Pointer(AOwner);
end;

function TWeakRef.Get: IUnknown;
begin
  Result := IUnknown(FOwner);
end;

function TWeakRef.IsAlive: Boolean;
begin
  Result := Assigned(FOwner);
end;

procedure TWeakRef._Clean;
begin
  FOwner := nil;
end;

{ TBasePublisher }

constructor TBasePublisher.Create(const AThreadSafe: Boolean);
begin
  if AThreadSafe then FCS := TCriticalSection.Create;
end;

destructor TBasePublisher.Destroy;
begin
  FreeAndNil(FCS);
  inherited;
end;

function TBasePublisher.GetItems: TWeakRefArr;
var i: Integer;
begin
  if assigned(FCS) then
  begin
    FCS.Enter;
    try
      SetLength(Result, FCount);
      for i := 0 to FCount - 1 do
        Result[i] := FItems[i];
    finally
      FCS.Leave;
    end;
  end
  else
    Result := FItems;
end;

procedure TBasePublisher.Grow(const NeedCapacity: Integer);
var Size: Integer;
begin
  Size := Length(FItems);
  if Size < NeedCapacity then
  Begin
    if Size < 8 then Size := 8;
    while Size < NeedCapacity do
      Size := Size * 2;
    SetLength(FItems, Size);
  End;
end;

procedure TBasePublisher.Pack;
var offset, i: Integer;
begin
  offset := 0;
  for i := 0 to FCount - 1 do
  begin
    if not IsAlive(FItems[i]) then
      Inc(offset)
    else
      if offset > 0 then FItems[i-offset] := FItems[i];
  end;
  FCount := FCount - offset;
  SetLength(FItems, FCount);
end;

procedure TBasePublisher.SafePack;
begin
  if assigned(FCS) then
  begin
    FCS.Enter;
    try
      Pack;
    finally
      FCS.Leave;
    end;
  end
  else
    Pack;
end;

procedure TBasePublisher.Subscribe(const ASubscriber: IWeakly);
begin
  if assigned(FCS) then
  begin
    FCS.Enter;
    try
      Grow(FCount + 1);
      FItems[FCount] := ASubscriber.WeakRef;
      Inc(FCount);
    finally
      FCS.Leave;
    end;
  end
  else
  begin
      Grow(FCount + 1);
      FItems[FCount] := ASubscriber.WeakRef;
      Inc(FCount);
  end;
end;

procedure TBasePublisher.Unsubscribe(const ASubscriber: IWeakly);
var i: Integer;
begin
  if assigned(FCS) then
  begin
    FCS.Enter;
    try
      for i := 0 to FCount - 1 do
        if FItems[i] = ASubscriber.WeakRef then FItems[i] := nil;
    finally
      FCS.Leave;
    end;
  end
  else
  begin
    for i := 0 to FCount - 1 do
      if FItems[i] = ASubscriber.WeakRef then FItems[i] := nil;
  end;
end;

{ TAutoPublisher }

class operator TAutoPublisher.Add(const APublisher: TAutoPublisher;
  const ASubscriber: IWeakly): Boolean;
begin
  APublisher.Publisher.Subscribe(ASubscriber);
  Result := True;
end;

class operator TAutoPublisher.Subtract(const APublisher: TAutoPublisher;
  const ASubscriber: IWeakly): Boolean;
begin
  APublisher.Publisher.Unsubscribe(ASubscriber);
  Result := True;
end;

end.
