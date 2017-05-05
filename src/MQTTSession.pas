unit MQTTSession;

interface

uses
  Classes, SysUtils, Generics.Collections, idIOHandler, IdComponent,
  idGlobal, MQTTParser, MQTTUtils, IntfEx, MQTTSessionPublisher,
  uTimer;
type
  TOnCheckUser = procedure(const aUserName, aPassword: UTF8String; var Allowed: Boolean) of object;
  TMQTTUnSubAckEvent = procedure(Sender: TObject; anID : Word) of object;

  TMQTTSession = class
  protected
    FOwner: TObject;
    FParser: TMQTTParser;
    FAlive: Boolean;
    FKeepAlive: Word;
    FClientID : UTF8String;
    FUsername: UTF8String;
    FPassword: UTF8String;
    FClean: Boolean;
    FHandler: TIdIOHandler;
    FOnLog: TMQTTMonEvent;
     {$IFDEF USE_OBJECT_ARC}[Weak]{$ENDIF}FSubscriptions: TDictionary<UTF8String, TMQTTQOSType>;
     {$IFDEF USE_OBJECT_ARC}[Weak]{$ENDIF}FReleasables: TDictionary<Word, IMessageItem>;
     {$IFDEF USE_OBJECT_ARC}[Weak]{$ENDIF}FInFlight: TDictionary<Word,TMQTTPacket>;
    FFlightTimer: TTimer;
    procedure DoFlight(Sender: TObject);
    procedure DoDisconnect(Sender: TObject);
    procedure SessinReset; virtual;
    procedure SetAlive(const Value: Boolean);
    procedure Log(aString: string);
    procedure OnPubAck(Sender: TObject; anID: Word);
    procedure OnPubRel(Sender: TObject; anID: Word);
    procedure OnPubComp(Sender: TObject; anID: Word);
    procedure OnPubRec(Sender: TObject; anID: Word);
    procedure OnSend(Sender: TObject; anID: Word; Retry: integer;
      aStream: TMemoryStream);
    function GetNextMessageID: Word;
    destructor Destroy; override;
  public
    constructor Create(AOwner: TObject; AHandler: TIdIOHandler); virtual;
    procedure Execute(const DataStream: TStream);
    property Alive: Boolean read FAlive write SetAlive;
    property ClientID : UTF8String read FClientID write FClientID;
    property Clean: Boolean read FClean write FClean;
    property KeepAlive: Word read FKeepAlive write FKeepAlive;
    property Handler: TIdIOHandler read FHandler write FHandler;
    property Username: UTF8String read FUsername write FUsername;
    property Parser: TMQTTParser read FParser;
    property Password: UTF8String read FPassword write FPassword;
    property OnLog: TMQTTMonEvent read FOnLog write FOnLog;
  end;

  TMQTTServerSession = class(TMQTTSession)
  private
    FOnCheckUser: TOnCheckUser;
    procedure SessinReset; override;
    procedure OnSubscribe(Sender: TObject; anID: Word; Topics: TStringList);
    procedure OnPing(Sender: TObject);
    procedure OnDisconnected(Sender: TObject);
    procedure OnPublish(Sender: TObject; aID: Word; aTopic: UTF8String; aMessage: String);
    procedure OnConnect(Sender: TObject; aProtocol: UTF8String; aVersion: Byte;
      aClientID, aUserName, aPassword: UTF8String; aKeepAlive: Word; aClean: boolean);
    procedure OnStatus(ASender: TObject; const AStatus: TIdStatus;
   const AStatusText: string);
    procedure OnUnsubscribe(Sender: TObject; anID: Word; Topics: TStringList);
    procedure OnSetWill(Sender: TObject; aTopic: UTF8String; aMessage: String;
      aQos: TMQTTQOSType; aRetain: boolean);
    procedure OnHeader(Sender: TObject; MsgType: TMQTTMessageType;
      Dup: boolean; Qos: TMQTTQOSType; Retain: boolean);
    procedure OnMon(Sender: TObject; aStr: string);
  public
    constructor Create(AOwner: TObject; AHandler: TIdIOHandler); override;
    property OnCheckUser: TOnCheckUser read FOnCheckUser write FOnCheckUser;
  end;

  TMQTTSessionAdapter = class(TWeaklyInterfacedObject, IMessageEvents)
  private
    FOwner: TObject;
    FSession: TMQTTServerSession;
    FHandler: TIdIOHandler;
  public
    constructor Create(AOwner: TObject; AHandler: TIdIOHandler);
    procedure OnAddItem(const ASender: IMessagePublisher; const AItem: IMessageItem);
    procedure OnClear(const ASender: IMessagePublisher);
    function GetImplementartor: Tobject;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    property Session: TMQTTServerSession read FSession;
    property Handler: TIdIOHandler read FHandler write FHandler;
  end;

  TMQTTClientSession = class(TMQTTSession)
  private
    FOnConnected: TMQTTAckEvent;
    FOnSubscribed: TNotifyEvent;
    FOnUnSubscribed: TNotifyEvent;
    FOnReceivedMessage: TMQTTPublishEvent;
    FAutoSubscribe: Boolean;
    procedure SessinReset; override;
    procedure OnConnAck(Sender: TObject; aCode: Byte);
    procedure OnSubAck(Sender: TObject; anID: Word; Qoss: array of TMQTTQosType);
    procedure OnUnsubAck (Sender: TObject; anID: Word);
    procedure OnDisconnected(Sender: TObject);
    procedure OnPublish(Sender: TObject; anID: Word; aTopic: UTF8String;
      aMessage: String);
  public
    constructor Create(AOwner: TObject; AHandler: TIdIOHandler); override;
    procedure Subscribe(aTopic: UTF8String; aQos: TMQTTQOSType); overload;
    procedure Subscribe(Topics: TStringList); overload;
    procedure Unsubscribe(aTopic: UTF8String); overload;
    procedure Unsubscribe(Topics: TStringList); overload;
    procedure Ping;
    procedure Publish(aTopic: UTF8String; aMessage: String; aQos: TMQTTQOSType; aRetain: Boolean = false);
    property AutoSubscribe: Boolean read FAutoSubscribe write FAutoSubscribe;
    property OnConnected: TMQTTAckEvent read FOnConnected write FOnConnected;
    property OnSubscribed: TNotifyEvent read FOnSubscribed write FOnSubscribed;
    property OnUnSubscribed: TNotifyEvent read FOnUnSubscribed write FOnUnSubscribed;
    property OnReceivedMessage: TMQTTPublishEvent read FOnReceivedMessage write FOnReceivedMessage;
    property Subscriptions: TDictionary<UTF8String, TMQTTQOSType> read FSubscriptions;

  end;

implementation

uses MQTTServer;


{ TMQTTSession }

constructor TMQTTSession.Create(AOwner: TObject; AHandler: TIdIOHandler);
begin
  FAlive:= False;
  FOwner := AOwner;
  FHandler := AHandler;
end;

destructor TMQTTSession.Destroy;
begin
  FFlightTimer.Free;
  FParser.Free;
  FSubscriptions.Free;
  FReleasables.Free;
  FInFlight.Free;
  inherited;
end;

procedure TMQTTSession.DoFlight(Sender: TObject);
var
  LPacket: TMQTTPacket;
begin
  if not FParser.CheckKeepAlive then
    DoDisconnect(self);

   for LPacket in FInFlight.Values do
   begin
     if LPacket.Counter > 0 then
     begin
       LPacket.Counter := LPacket.Counter - 1;
       if LPacket.Counter = 0 then
       begin
         LPacket.Retries := LPacket.Retries + 1;
         if LPacket.Retries <= FParser.MaxRetries then
         begin
           if LPacket.Publishing then
           begin
             FInFlight.Remove(LPacket.ID);
             Log('Message ' + IntToStr (LPacket.ID) + ' disposed of..');
             Log('Re-issuing Message ' + inttostr (LPacket.ID) + ' Retry ' + inttostr (LPacket.Retries));
             SetDup(LPacket.Data, true);
             OnSend(Self, LPacket.ID, LPacket.Retries, LPacket.Data);
             LPacket.Free;
           end else
           begin
             Log('Re-issuing PUBREL Message ' + inttostr (LPacket.ID) + ' Retry ' + inttostr (LPacket.Retries));
             FParser.SendPubRel(LPacket.ID, True);
             LPacket.Counter := FParser.RetryTime;
           end;
         end else
           DoDisconnect(self);
       end;
     end;
   end;
end;

procedure TMQTTSession.DoDisconnect(Sender: TObject);
begin
  FHandler.Close;
//  FConnectionContext.Connection.Disconnect;
end;

procedure TMQTTSession.Execute(const DataStream: TStream);
begin
  Fparser.Parse(DataStream);
end;

function TMQTTSession.GetNextMessageID: Word;
var
  LUnused: Boolean;
  LMessageID, LCurID: Word;
begin
  LMessageID := 0;
  repeat
    LUnused := true;
    LMessageID := LMessageID + 1;
    for LCurID in FInFlight.Keys do
    begin
      if LCurID = LMessageID then
      begin
        LUnused := false;
        break;
      end;
    end;
  until LUnused;
  Result := LMessageID;
end;

procedure TMQTTSession.Log(aString: string);
begin
  if assigned(FOnLog) then FOnLog(self, aString);
end;

procedure TMQTTSession.SessinReset;
begin
  FreeAndNil(FParser);
  FParser := TMQTTParser.Create;
  FreeAndNil(FSubscriptions);
  FSubscriptions := TDictionary<UTF8String, TMQTTQOSType>.Create;
  FreeAndNil(FReleasables);
  FReleasables := TDictionary<Word, IMessageItem>.Create;
  FreeAndNil(FInFlight);
  FInFlight := TDictionary<Word,TMQTTPacket>.Create;
  FreeAndNil(FFlightTimer);
  FFlightTimer := TTimer.Create;
  FFlightTimer.Interval := 100;
  FFlightTimer.OnTimer := DoFlight;
end;

procedure TMQTTSession.SetAlive(const Value: Boolean);
begin
  if FAlive <> Value then
  begin
    FAlive := Value;
    if FAlive then
    begin
      FFlightTimer.Active := True;
    end else
    begin
      FFlightTimer.Active := False;
    end;
  end;
end;

procedure TMQTTSession.OnPubAck(Sender: TObject; anID: Word);
begin
  FInFlight.Remove(anID);
  Log(UTF8string(ClientID) + ' ACK Message ' + anID.ToString + ' disposed of.');
end;

procedure TMQTTSession.OnPubComp(Sender: TObject; anID: Word);
begin
  FInFlight.Remove(anID);
  Log('COMP Message ' + anID.ToString + ' disposed of.');
end;

procedure TMQTTSession.OnPubRec(Sender: TObject; anID: Word);
var
  LPacket: TMQTTPacket;
begin
  if FInFlight.TryGetValue(anID, LPacket) then
    begin
      LPacket.Counter := FParser.RetryTime;
      if LPacket.Publishing then
        begin
          LPacket.Publishing := false;
          Log('REC Message ' + anID.ToString + ' recorded.');
        end
      else
        Log('REC Message ' + anID.ToString + ' already recorded.');
    end
  else
    Log('REC Message ' + anID.ToString + ' not found.');
  FParser.SendPubRel(anID);
end;

procedure TMQTTSession.OnPubRel(Sender: TObject; anID: Word);
var
  LMessage: IMessageItem;
begin
  if FReleasables.TryGetValue(anID, LMessage) then
  begin
      Log('REL Message ' + IntToStr (anID) + ' publishing @ ' + QoSName(LMessage.Qos));
//      if Assigned(FOnMsg) then FOnMsg (Self, aMsg.Topic, aMsg.Message, aMsg.Qos, aMsg.Retained);
      FReleasables.Remove(anID);
      LMessage := nil;
      Log('REL Message ' + anID.ToString + ' removed from storage.');
  end else
    Log('REL Message ' + anID.ToString + ' has been already removed from storage.');
  FParser.SendPubComp(anID);
end;

procedure TMQTTSession.OnSend(Sender: TObject; anID: Word; Retry: integer;
  aStream: TMemoryStream);
var
  x: Byte;
begin
  if FHandler.Opened then
    begin
      aStream.Seek (0, soFromBeginning);
      aStream.Read (x, 1);
      if (TMQTTQOSType((x and $06) shr 1) in [qtAT_LEAST_ONCE, qtEXACTLY_ONCE]) and
         (TMQTTMessageType((x and $f0) shr 4) in [{mtPUBREL,} mtPUBLISH, mtSUBSCRIBE, mtUNSUBSCRIBE]) and
         (anID > 0) then
        begin
          FInFlight.Add(anID, TMQTTPacket.Create(anID, aStream, Retry, FParser.RetryTime));
          Log('Message ' + anID.ToString + ' created.');
        end;
      aStream.Position := 0;
      FHandler.Write(aStream, aStream.Size);
//      Sleep (0);
    end;
end;

{ TMQTTServerSession }

constructor TMQTTServerSession.Create(AOwner: TObject; AHandler: TIdIOHandler);
begin
  inherited;
  FHandler.OnStatus := OnStatus;
//  FHandler.OnDisconnected := OnDisconnected;
  SessinReset;
end;

procedure TMQTTServerSession.OnConnect(Sender: TObject; aProtocol: UTF8String;
  aVersion: Byte; aClientID, aUserName, aPassword: UTF8String; aKeepAlive: Word;
  aClean: boolean);
var
  FAllowed: Boolean;
begin
  FAllowed := False;
  if Assigned(FOnCheckUser) then
    FOnCheckUser(aUserName, aPassword, FAllowed);
{  else
    if (aUserName = '') and (aPassword = '') then
      FAllowed := True;
}
  if FAllowed then
  begin
    if aVersion < MinVersion then
    begin
        Log('Client Disconnected. Client version rejected ' + aVersion.ToString + ' < ' + MinVersion.ToString);
        FParser.SendConnAck(rcPROTOCOL);  // identifier rejected
        DoDisconnect(self);
    end
    else if (aClientID = '') or (length(aClientID) > 32) then
    begin
        Log('Client Disconnected. Identifier length rejected. ' + Length(aClientID).ToString);
        FParser.SendConnAck(rcIDENTIFIER);  // identifier rejected
        DoDisconnect(self);
    end
    else if (FClientID <> '') and (FClientID <> aClientID) then
    begin
        Log('Client Disconnected. Client session is already present ' + aClientID);
        FParser.SendConnAck(rcIDENTIFIER);  // identifier rejected
        DoDisconnect(self);
    end
    else
    begin
        Log(UTF8ToString(aClientID) + '@UserName: '  + UTF8ToString(aUserName) + ' Password: ' + UTF8ToString(aPassword));
        FUsername := aUserName;
        FPassword := aPassword;
        FClientID := aClientID;
        FKeepAlive := aKeepAlive;
        FClean := aClean;
        Log('Clean ' + ny[aClean]);
        if not aClean then
          SessinReset;
        FParser.SendConnAck(rcACCEPTED);

        Alive := True;
        Log('Connection Accepted.');
    end;
  end else
  begin
     Log('Client Disconnected. Access is not allowed for ' + aUserName);
    FParser.SendConnAck(rcUSER);
    DoDisconnect(self);
  end;
end;

procedure TMQTTServerSession.OnDisconnected(Sender: TObject);
begin
  Log('Client Disconnected.  Graceful ' + ny[FHandler.ClosedGracefully]);
 //ToDO: Need Store session
{  if (FInFlight.Count > 0) or (FReleasables.Count > 0) then
  begin
    if Assigned (FOnStoreSession) then
      FOnStoreSession (FClientID)
    else
      StoreSession(FClientID);
  end;
}
  if not FHandler.ClosedGracefully then
    MessagePublisher.SetItem(TMQTTCustomServer(FOwner).WillMessage);
end;

procedure TMQTTServerSession.OnHeader(Sender: TObject; MsgType: TMQTTMessageType;
  Dup: boolean; Qos: TMQTTQOSType; Retain: boolean);
begin

end;

procedure TMQTTServerSession.OnMon(Sender: TObject; aStr: string);
begin
  log(UTF8ToString(FClientID) +'@'+ #9 + aStr);
end;

procedure TMQTTServerSession.OnPing(Sender: TObject);
begin
  FParser.SendPingResp;
end;

procedure TMQTTServerSession.OnPublish(Sender: TObject; aID: Word; aTopic: UTF8String;
  aMessage: String);
var
  LMessage: TMessageItem;
  LReleasableMessage: IMessageItem;
begin
  if not checkPublishTopic(aTopic) then
  begin
    DoDisconnect(self);
    Exit;
  end;

  LMessage := TMessageItem.Create(0, FParser.RxQos, aTopic, aMessage, FParser.RxRetain);
  if FParser.RxRetain then
    begin
      Log('Retaining "' + UTF8ToString(aTopic) + '" @ ' + QOSName(FParser.RxQos));
      TMQTTCustomServer(FOwner).DeleteRetainedMessage(LMessage.Topic);
      TMQTTCustomServer(FOwner).AddRetainedMessage(LMessage);
    end;
  case FParser.RxQos of
    qtAT_MOST_ONCE  :
       MessagePublisher.SetItem(LMessage);
    qtAT_LEAST_ONCE :
    begin
        FParser.SendPubAck(aID);
        MessagePublisher.SetItem(LMessage);
    end;
    qtEXACTLY_ONCE  :
    begin
      if not FReleasables.TryGetValue(aID, LReleasableMessage) then
      begin
       FReleasables.Add(aID, LMessage);
       Log(UTF8ToString(FParser.ClientID) + ' Message ' + IntToStr (aID) + ' stored and idle.');
      end else
       Log(UTF8ToString(FParser.ClientID) + ' Message ' + IntToStr (aID) + ' already stored.');
      FParser.SendPubRec(aID);
    end;
  end;
end;


procedure TMQTTServerSession.OnSetWill(Sender: TObject; aTopic: UTF8String; aMessage: String;
  aQos: TMQTTQOSType; aRetain: boolean);
begin
  TMQTTCustomServer(FOwner).SetWill(aTopic, aMessage, aQoS, aRetain);
  FParser.SetWill(aTopic, aMessage, aQoS, aRetain);
end;

procedure TMQTTServerSession.OnStatus(ASender: TObject;
  const AStatus: TIdStatus; const AStatusText: string);
begin
  case AStatus of
    hsDisconnected: onDisconnected(ASender);
  end;
end;

procedure TMQTTServerSession.OnSubscribe(Sender: TObject; anID: Word;
  Topics: TStringList);
var
  I: Integer;
  LQosArray: array of TMQTTQOSType;
  LMsg: IMessageItem;
  LQoS: TMQTTQOSType;
begin
  SetLength(LQosArray, Topics.Count);
  for I := 0 to Topics.Count -1 do
  begin
    if checkTopic(UTF8Encode(Topics.Strings[I])) then
    begin
      if FSubscriptions.ContainsKey(UTF8Encode(Topics.Strings[I])) then
        FSubscriptions.Remove(UTF8Encode(Topics.Strings[I]));
      FSubscriptions.Add(UTF8Encode(Topics.Strings[I]), TMQTTQOSType(Topics.Objects[I]));
      LQosArray[I] := TMQTTQOSType(Topics.Objects[I]);
      Log(UTF8ToString(FClientID) + '@Subscribed on topic: ' + Topics.Strings[I] + ' QoS: ' + QoSName(TMQTTQOSType(Topics.Objects[I])));
    end else
      LQosArray[I] := qtFAILURE;

    LMsg := TMQTTCustomServer(FOwner).GetRetainedMessage(UTF8Encode(Topics.Strings[I]));
    if assigned(LMsg) then
    begin
      if  TMQTTQOSType(Topics.Objects[I]) < LMsg.QoS then
        LQos :=  TMQTTQOSType(Topics.Objects[I])
      else
       LQos := LMsg.QoS;
       Log(UTF8ToString(FClientID) + '@Publich retained message on topic: ' + Topics.Strings[I] + ' QoS: ' + QoSName(TMQTTQOSType(Topics.Objects[I])));

       FParser.SendPublish(GetNextMessageID, LMsg.Topic, LMsg.Message, LQos, false, true);
    end;
  end;
  FParser.SendSubAck(anID, LQosArray);
end;


procedure TMQTTServerSession.OnUnsubscribe(Sender: TObject; anID: Word;
  Topics: TStringList);
var
  I: Integer;
begin
  for I := 0 to Topics.Count -1 do
    if FSubscriptions.ContainsKey(UTF8Encode(Topics.Strings[I])) then
    begin
      FSubscriptions.Remove(UTF8Encode(Topics.Strings[I]));
      Log(UTF8ToString(FClientID) + '@Unsubscribed: ' + Topics.Strings[I]);
    end else
      Log(UTF8ToString(FClientID)
       + '@Unsubscribed: ' + Topics.Strings[I] + ' not found');
  FParser.SendUnsubAck(anID);
end;

procedure TMQTTServerSession.SessinReset;
begin
  inherited;
  FParser.OnPubAck := OnPubAck;
  FParser.OnPubRel := OnPubRel;
  FParser.OnPubRec := OnPubRec;
  FParser.OnPubComp := OnPubComp;
  FParser.OnConnect := OnConnect;
  FParser.OnPublish := OnPublish;
  FParser.OnPing := OnPing;

  FParser.OnDisconnect := DoDisconnect;
  FParser.OnSubscribe := OnSubscribe;
  FParser.OnUnsubscribe := OnUnsubscribe;
  FParser.OnSetWill := OnSetWill;

  FParser.OnHeader := OnHeader;
  FParser.OnMon := OnMon;
  FParser.OnSend := OnSend;
end;


{ TMQTTSessionAdapter }

procedure TMQTTSessionAdapter.AfterConstruction;
begin
  inherited;
  FSession := TMQTTServerSession.Create(FOwner, FHandler);
  MessagePublisher.MessageEvents + Self;
end;

procedure TMQTTSessionAdapter.BeforeDestruction;
begin
  inherited;
  FreeAndNil(FSession);
  FHandler := nil;
end;

constructor TMQTTSessionAdapter.Create(AOwner: TObject; AHandler: TIdIOHandler);
begin
  FOwner := AOwner;
  FHandler := AHandler;
end;

function TMQTTSessionAdapter.GetImplementartor: Tobject;
begin
  Result := Self;
end;

procedure TMQTTSessionAdapter.OnAddItem(const ASender: IMessagePublisher;
  const AItem: IMessageItem);
var
  LStr: Utf8String;
  LQoS: TMQTTQOSType;
begin
   for LStr in FSession.FSubscriptions.Keys do
    if isAllowedTopic(AItem.Topic, LStr) then
    begin
      LQoS := FSession.FSubscriptions.Items[LStr];
      FSession.Log('Publishing to Client ' + UTF8ToString(FSession.FParser.ClientID) + ' "' + UTF8ToString(AItem.Topic) + '"');
      if LQos > AItem.QoS then
        LQos := AItem.QoS;
      FSession.FParser.SendPublish(FSession.GetNextMessageID, AItem.Topic, AItem.Message, LQos, false, AItem.Retained);
      break;
    end;
end;

procedure TMQTTSessionAdapter.OnClear(const ASender: IMessagePublisher);
begin

end;

{ TMQTTClientSession }

constructor TMQTTClientSession.Create(AOwner: TObject; AHandler: TIdIOHandler);
begin
  inherited;
  SessinReset;
//  FConnectionContext.Connection.OnDisconnected := OnDisconnected;
end;

procedure TMQTTClientSession.OnConnAck(Sender: TObject; aCode: Byte);
var
  i : integer;
  x : cardinal;
  LTopic: UTF8String;
begin
  Log('Connection ' + codenames(aCode));
  if aCode = rcACCEPTED then
  begin
    if (AutoSubscribe) and (FSubscriptions.Count > 0) then
      for LTopic in FSubscriptions.Keys do
        FParser.SendSubscribe(GetNextMessageID, LTopic, FSubscriptions.Items[LTopic]);
  end else
   DoDisconnect(self);
  if assigned(FOnConnected) then FOnConnected(Self, aCode);
end;

procedure TMQTTClientSession.OnDisconnected(Sender: TObject);
begin
  Log('Client Disconnected.  Graceful ' + ny[FHandler.ClosedGracefully]);
end;

procedure TMQTTClientSession.OnPublish(Sender: TObject; anID: Word;
  aTopic: UTF8String; aMessage: String);
begin
  Log('Message publish ' + IntToStr (anID));
  if assigned(FOnReceivedMessage) then FOnReceivedMessage(Self, anID, aTopic, aMessage);
end;

procedure TMQTTClientSession.OnSubAck(Sender: TObject; anID: Word;
  Qoss: array of TMQTTQosType);
begin
  FInFlight.Remove(anID);
  Log('Message ' + IntToStr (anID) + ' disposed of.');
  if assigned(FOnSubscribed) then FOnSubscribed(Self);
end;

procedure TMQTTClientSession.OnUnsubAck(Sender: TObject; anID: Word);
begin
  FInFlight.Remove(anID);
  Log('Message ' + IntToStr (anID) + ' disposed of.');
  if assigned(FOnUnSubscribed) then FOnUnSubscribed(Self);
end;

procedure TMQTTClientSession.Ping;
begin
  FParser.SendPing;
end;

procedure TMQTTClientSession.Publish(aTopic: UTF8String; aMessage: String;
  aQos: TMQTTQOSType; aRetain: Boolean);
begin
  FParser.SendPublish(GetNextMessageID, aTopic, aMessage, aQos, false, aRetain);
end;

procedure TMQTTClientSession.SessinReset;
begin
  inherited;
  FParser.OnPubAck := OnPubAck;
  FParser.OnPubRel := OnPubRel;
  FParser.OnPubRec := OnPubRec;
  FParser.OnPubComp := OnPubComp;
  FParser.OnPublish := OnPublish;
  FParser.OnConnAck := OnConnAck;
  FParser.OnSubAck := OnSubAck;
  FParser.OnUnsubAck := OnUnsubAck;
  FParser.OnDisconnect := DoDisconnect;
  FParser.OnSend := OnSend;
  FKeepAlive := 100;
  FClientID  := '';
  FUsername := '';
  FPassword := '';
  FClean := False;
end;

procedure TMQTTClientSession.Subscribe(Topics: TStringList);
var
  LTopic: UTF8String;
  LQos: TMQTTQOSType;
  i: Integer;
begin
  for I := 0 to Topics.Count -1 do
    Subscribe(UTF8Encode(Topics.Strings[I]), TMQTTQOSType(Topics.Objects[I]));
end;

procedure TMQTTClientSession.Subscribe(aTopic: UTF8String; aQos: TMQTTQOSType);
var
  LID: Word;
begin
  if aTopic = '' then exit;
  LID := GetNextMessageID;
  if FSubscriptions.ContainsKey(aTopic) then
    FSubscriptions.Remove(aTopic);
  FSubscriptions.Add(aTopic, aQos);
  FParser.SendSubscribe(LID, aTopic, aQos);
end;

procedure TMQTTClientSession.Unsubscribe(Topics: TStringList);
var
  I: Integer;
begin
  for I := 0 to Topics.Count -1 do
    FParser.SendUnsubscribe(GetNextMessageID, UTF8Encode(Topics.Strings[I]));
end;

procedure TMQTTClientSession.Unsubscribe(aTopic: UTF8String);
begin
  if aTopic = '' then exit;
  if FSubscriptions.ContainsKey(aTopic) then
    FSubscriptions.Remove(aTopic);
  FParser.SendUnsubscribe(GetNextMessageID, aTopic);
end;

end.
