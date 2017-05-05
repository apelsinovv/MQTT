unit MQTTClient;

interface
uses Classes, Generics.Collections, SysUtils, MQTTParser, MQTTUtils, MQTTSession,
  MQTTSessionPublisher, IdTCPClient, IdTCPConnection, IdIOHandler, idGlobal, idComponent;

type
  TMQTTCustomClient = class(TIdTCPClientCustom)
  private
    FSession: TMQTTClientSession;
    FRetained: TThreadList<IMessageItem>;
    FOnLog: TMQTTMonEvent;
    FAutoSubscribe: Boolean;
    FClientID: UTF8String;
    FUserName,
    FPassword: UTF8String;
    FCleanSession: Boolean;
    FKeepAlive: Word;

    FOnConnected: TMQTTAckEvent;
    FOnSubscribed: TNotifyEvent;
    FOnUnSubscribed: TNotifyEvent;
    FOnReceivedMessage: TMQTTPublishEvent;
    procedure OnStatus(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: string);
    procedure DoOnConnected; override;
    function DoExecute(FHandler: TIdIOHandler): Boolean;
    procedure DoConnected(Sender: TObject; aCode: Byte);
    procedure DoSubscribed(Sender: TObject);
    procedure DoUnSubscribed(Sender: TObject);
    procedure DoReceivedMessage(Sender: TObject; anID: Word; aTopic: UTF8String;
      aMessage: String);

    procedure DoDisconnect;
    procedure DoLog(Sender: TObject; AString: String);
  public
    destructor Destroy; override;
    procedure SetWill(aTopic: UTF8String; aMessage: String; aQos: TMQTTQOSType;
      aRetain: boolean);
    property Retained: TThreadList<IMessageItem> read FRetained;
    property OnLog: TMQTTMonEvent read FOnLog write FOnLog;
    property ClientID: UTF8String read FClientID write FClientID;
    property AutoSubscribe: Boolean read FAutoSubscribe write FAutoSubscribe;
    property Username: UTF8String read FUsername write FUsername;
    property Password: UTF8String read FPassword write FPassword;
    property CleanSession: Boolean read FCleanSession write FCleanSession;
    property KeepAlive: Word read FKeepAlive write FKeepAlive;
    property Session: TMQTTClientSession read FSession;

    property OnConnected: TMQTTAckEvent read FOnConnected write FOnConnected;
    property OnSubscribed: TNotifyEvent read FOnSubscribed write FOnSubscribed;
    property OnUnSubscribed: TNotifyEvent read FOnUnSubscribed write FOnUnSubscribed;
    property OnReceivedMessage: TMQTTPublishEvent read FOnReceivedMessage write FOnReceivedMessage;

  published
    property Host;
    property Port;
  end;

implementation
uses Threading;
{ TMQTTCustomClient }

destructor TMQTTCustomClient.Destroy;
begin

  inherited;
end;

procedure TMQTTCustomClient.DoConnected(Sender: TObject; aCode: Byte);
begin
 if assigned(FOnConnected) then FOnConnected(self, aCode);
end;

procedure TMQTTCustomClient.DoDisconnect;
begin
  inherited;
  if FSession <> nil then
  begin
    FSession.Alive := False;
    if FSession.Clean then
      FSession.Free;
  end;
end;

function TMQTTCustomClient.DoExecute(FHandler: TIdIOHandler): Boolean;
var
 LConn: TIdTCPConnection;
 LBuffer: TIdBytes;
 LMsgType: TMQTTMessageType;
 LDup: Boolean;
 LQoS: TMQTTQOSType;
 LRetain: Boolean;
begin
  Result := False;
  FIOHandler.ReadTimeout := 500;
  TTask.Run(
//  TThread.CreateAnonymousThread(
    procedure()
    begin
      while FHandler.Opened do
      begin
        if not assigned(FSession) then
        begin
          FSession := TMQTTClientSession.Create(self, FHandler);
          FSession.ClientID := FClientID;
          FSession.Clean := FCleanSession;
          FSession.KeepAlive := FKeepAlive;
          FSession.Username := FUserName;
          FSession.Password := FPassword;
          FSession.AutoSubscribe := FAutoSubscribe;
          FSession.Parser.SendConnect(FClientID, FUserName, FPassword, FKeepAlive, FCleanSession);
          FSession.OnLog := DoLog;
          FSession.OnConnected := DoConnected;
          FSession.OnSubscribed := DoSubscribed;
          FSession.OnUnSubscribed := DoUnSubscribed;
          FSession.OnReceivedMessage := DoReceivedMessage;
        end;
        SetLength(LBuffer, 0);
        FIOHandler.ReadBytes(LBuffer, -1, False);
        if length(LBuffer) > 0 then
        begin
                TThread.Synchronize(nil,
                procedure()
                var
                  LStrm: TMemoryStream;
                begin
                  LStrm := TMemoryStream.Create;
                  try
                    LStrm.WriteData(LBuffer, length(LBuffer));
                    LStrm.Position := 0;
                    ReadHeader(LStrm, LMsgType, LDup, LQoS, LRetain);
                    LStrm.Position := 0;
                   FSession.Execute(LStrm);
                  finally
                    LStrm.Free;
                  end;
                end);
        end;
        sleep(500);
      end;
    end
  );
  //.Start;
end;

procedure TMQTTCustomClient.DoLog(Sender: TObject; AString: String);
var
  LString: string;
begin
  if assigned(FOnLog) then
  begin
     if Sender is TMQTTSession then
       LString := Format('%s'+#9+'%s'+#9+'%s', [DateTimeToStr(now), TMQTTSession(Sender).ClientID, AString])
     else
       LString := Format('%s'+#9+'%s', [DateTimeToStr(now), AString]);
     FOnLog(self, LString);
  end;
end;

procedure TMQTTCustomClient.DoOnConnected;
begin
  inherited;
  DoExecute(IOHandler)
end;

procedure TMQTTCustomClient.DoReceivedMessage(Sender: TObject; anID: Word;
  aTopic: UTF8String; aMessage: String);
begin
 if assigned(FOnReceivedMessage) then FOnReceivedMessage(self, anID, aTopic, aMessage);
end;

procedure TMQTTCustomClient.DoSubscribed(Sender: TObject);
begin
 if assigned(FOnSubscribed) then FOnSubscribed(Sender);
end;

procedure TMQTTCustomClient.DoUnSubscribed(Sender: TObject);
begin
 if assigned(FOnUnSubscribed) then FOnUnSubscribed(Sender);
end;

procedure TMQTTCustomClient.OnStatus(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: string);
begin
  DOLog(self, AStatusText);
  case AStatus of
    hsDisconnected: DoDisconnect;
  end;

end;

procedure TMQTTCustomClient.SetWill(aTopic: UTF8String; aMessage: String;
  aQos: TMQTTQOSType; aRetain: boolean);
begin
  FSession.Parser.SetWill(aTopic, aMessage, aQos, aRetain);
end;

end.
