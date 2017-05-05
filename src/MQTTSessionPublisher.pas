unit MQTTSessionPublisher;

interface
uses
//  Windows,
  SysUtils,
  Classes,
  MQTTUtils,
  IntfEx;

type
  IMessageItem = interface
  ['{CCCE1742-CD9B-41EA-9713-0B2C55840A20}']
    function GetID: Word;
    procedure SetID(Value: Word);
    function GetQoS: TMQTTQOSType;
    procedure SetQoS(Value: TMQTTQOSType);
    function GetRetained: Boolean;
    procedure SetRetained(Value: Boolean);
    function GetCounter: Cardinal;
    procedure SetCounter(Value: Cardinal);
    function GetRetries: Integer;
    procedure SetRetries(Value: Integer);
    function GetTopic: UTF8String;
    procedure SetTopic(Value: UTF8String);
    function GetMessage: String;
    procedure SetMessage(Value: String);

    property ID: Word read GetID write SetID;
    property QoS: TMQTTQOSType read GetQoS write SetQoS;
    property Retained: Boolean read GetRetained write SetRetained;
    property Counter: Cardinal read GetCounter write SetCounter;
    property Retries: Integer read GetRetries write SetRetries;
    property Topic: UTF8String read GetTopic write SetTopic;
    property Message: String read GetMessage write SetMessage;
  end;

  TMessageItem = class(TInterfacedObject, IMessageItem)
  private
    FID: Word;
    FQoS : TMQTTQOSType;
    FRetained : Boolean;
    FCounter : Cardinal;
    FRetries : Integer;
    FTopic: UTF8String;
    FMessage: String;
    function GetQoS: TMQTTQOSType;
    procedure SetQoS(Value: TMQTTQOSType);
    function GetRetained: Boolean;
    procedure SetRetained(Value: Boolean);
    function GetCounter: Cardinal;
    procedure SetCounter(Value: Cardinal);
    function GetRetries: Integer;
    procedure SetRetries(Value: Integer);
    function GetID: Word;
    procedure SetID(Value: Word);
    function GetTopic: UTF8String;
    procedure SetTopic(Value: UTF8String);
    function GetMessage: String;
    procedure SetMessage(Value: String);
  public
    constructor Create(const AID: Word; const AQoS: TMQTTQOSType;
      const ATopic: UTF8String; const AMessage: String; ARetained: Boolean = False);
    property ID: Word read GetID write SetID;
    property QoS: TMQTTQOSType read GetQoS write SetQoS;
    property Retained: Boolean read GetRetained write SetRetained;
    property Counter: Cardinal read GetCounter write SetCounter;
    property Retries: Integer read GetRetries write SetRetries;
    property Topic: UTF8String read GetTopic write SetTopic;
    property Message: String read GetMessage write SetMessage;
  end;

  IMessagePublisher = interface;

  IMessageEvents = interface
  ['{5E753706-98D2-4693-9768-B8BBEC32B27E}']
    function GetImplementartor: Tobject;
    procedure OnAddItem(const ASender: IMessagePublisher; const AItem: IMessageItem);
    procedure OnClear(const ASender: IMessagePublisher);
  end;

  IMessagePublisher = interface
     function GetItem: IMessageItem;
     procedure SetItem(const Item: IMessageItem);
     procedure ResetItem;
     function MessageEvents: TAutoPublisher;
  end;

  TMessagePublisher = class(TInterfacedObject, IMessagePublisher)
  private
    FItem: IMessageItem;
    FEvents: TAutoPublisher;
  public
    function GetItem: IMessageItem;
    procedure SetItem(const Item: IMessageItem);
    procedure ResetItem;
    function MessageEvents: TAutoPublisher;
    constructor Create;
    destructor Destroy; override;
  end;

function MessagePublisher: IMessagePublisher;

implementation

uses Generics.Collections;

type
  TMessageEventsBroadcaster = class(TBasePublisher, IMessageEvents)
  private
    function GetImplementartor: Tobject;
    procedure OnAddItem(const ASender: IMessagePublisher; const AItem: IMessageItem);
    procedure OnClear(const ASender: IMessagePublisher);
  end;


var MPublisher: IMessagePublisher;

function MessagePublisher: IMessagePublisher;
begin
  if MPublisher = nil then
    MPublisher := TMessagePublisher.Create;
  Result := MPublisher;
end;

{ TMessageEventsBroadcaster }

function TMessageEventsBroadcaster.GetImplementartor: Tobject;
begin
  Result := Self;
end;

procedure TMessageEventsBroadcaster.OnAddItem(const ASender: IMessagePublisher;
  const AItem: IMessageItem);
var
  arr: TWeakRefArr;
  i: Integer;
  ev: IMessageEvents;
begin
  arr := GetItems;
  for i := 0 to Length(arr) - 1 do
    if IsAlive(arr[i]) then
      if Supports(arr[i].Get, IMessageEvents, ev) then
        ev.OnAddItem(ASender, AItem);
end;

procedure TMessageEventsBroadcaster.OnClear(const ASender: IMessagePublisher);
var
  arr: TWeakRefArr;
  i: Integer;
  ev: IMessageEvents;
begin
  arr := GetItems;
  for i := 0 to Length(arr) - 1 do
    if IsAlive(arr[i]) then
      if Supports(arr[i].Get, IMessageEvents, ev) then
        ev.OnClear(ASender);
end;

{ TMessageItem }

constructor TMessageItem.Create(const AID: Word; const AQoS: TMQTTQOSType;
  const ATopic: UTF8String; const AMessage: String; ARetained: Boolean = False);
begin
  FID := AID;
  FQoS := AQoS;
  FRetained := ARetained;
  FCounter := 0;
  FRetries := 0;
  FTopic := ATopic;
  FMessage := AMessage;
end;

function TMessageItem.GetCounter: Cardinal;
begin
  Result := FCounter;
end;

function TMessageItem.GetID: Word;
begin
  Result := FID;
end;

function TMessageItem.GetMessage: String;
begin
  Result := FMessage;
end;


function TMessageItem.GetQoS: TMQTTQOSType;
begin
  Result := FQoS;
end;

function TMessageItem.GetRetained: Boolean;
begin
  Result := FRetained;
end;

function TMessageItem.GetRetries: Integer;
begin
  Result := FRetries;
end;

function TMessageItem.GetTopic: UTF8String;
begin
  Result := FTopic;
end;

procedure TMessageItem.SetCounter(Value: Cardinal);
begin
  FCounter := Value;
end;

procedure TMessageItem.SetID(Value: Word);
begin
  FID := Value;
end;

procedure TMessageItem.SetMessage(Value: String);
begin
  FMessage := Value;
end;

procedure TMessageItem.SetQoS(Value: TMQTTQOSType);
begin
  FQoS := Value;
end;

procedure TMessageItem.SetRetained(Value: Boolean);
begin
  FRetained := Value;
end;

procedure TMessageItem.SetRetries(Value: Integer);
begin
  FRetries := Value;
end;

procedure TMessageItem.SetTopic(Value: UTF8String);
begin
  FTopic := Value;
end;

{ TMessagePublisher }

constructor TMessagePublisher.Create;
begin
  FItem := nil;
  FEvents.Publisher := TMessageEventsBroadcaster.Create(True);
end;

destructor TMessagePublisher.Destroy;
begin
  inherited;
end;

function TMessagePublisher.GetItem: IMessageItem;
begin
  Result := FItem;
end;

function TMessagePublisher.MessageEvents: TAutoPublisher;
begin
  Result := FEvents;
end;

procedure TMessagePublisher.ResetItem;
begin
  FItem := nil;
end;

procedure TMessagePublisher.SetItem(const Item: IMessageItem);
begin
  FItem := Item;
  (FEvents.Publisher as IMessageEvents).OnAddItem(Self, Item);
end;

end.
