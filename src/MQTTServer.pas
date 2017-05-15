unit MQTTServer;

interface
uses
  Classes, Generics.Collections, SysUtils, MQTTParser, MQTTUtils, MQTTSession,
  idTCPServer, idCustomTCPServer, IdTCPConnection, idContext, idIOHandler, idGlobal, idComponent, MQTTSessionPublisher;

type

  TMQTTCustomServer = class(TidCustomTCPServer)
  strict private
    procedure RemoveSession(Index: Integer);
    function GetSession(AClientID: UTF8String): TMQTTSessionAdapter;
    function GetSessionIndex(AClientID: UTF8String): Integer;
    procedure AddSession(const ASession: IMessageEvents);
    procedure UpdateSessionHandler(const ASession: TMQTTSessionAdapter; const AHandler: TIdIOHandler);
  private
    FSessions: TArray<IUnknown>;
    FWillMessage: IMessageItem;
    FWillFlag: boolean;
    FRetained: TThreadList<IMessageItem>;
    FOnCheckUser: TOnCheckUser;
    FOnLog: TMQTTMonEvent;
    procedure OnStatus(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: string);
    function DoExecute(AContext: TIdContext): Boolean; override;
    procedure DoDisconnect(AContext: TIdContext); override;
    function GetSesion(AHandler: TIdIOHandler): TMQTTSessionAdapter;
    procedure DoLog(Sender: TObject; AString: String);
    procedure DoSessionNotify(Sender: TObject; const Item: TMQTTSessionAdapter; Action: TCollectionNotification);
  public
    destructor Destroy; override;
    function GetRetainedMessage(const ATopoc: UTF8String): IMessageItem;
    function AddRetainedMessage(const Value: IMessageItem): Boolean;
    function DeleteRetainedMessage(const ATopic: UTF8String): Boolean;
    procedure SetWill(aTopic: UTF8String; aMessage: String; aQos: TMQTTQOSType;
      aRetain: boolean);

    property WillMessage: IMessageItem read FWillMessage;
    property Retained: TThreadList<IMessageItem> read FRetained;
    property OnCheckUser: TOnCheckUser read FOnCheckUser write FOnCheckUser;
    property OnLog: TMQTTMonEvent read FOnLog write FOnLog;
  end;

implementation
uses IdResourceStringsCore;

{ TMQTTCustomServer }

function TMQTTCustomServer.AddRetainedMessage(
  const Value: IMessageItem): Boolean;
var
  LLockLst: TList<IMessageItem>;
begin
  Result := False;
  if not assigned(FRetained) then
   FRetained := TThreadList<IMessageItem>.Create;
  DeleteRetainedMessage(Value.Topic);
  LLockLst := FRetained.LockList;
  try
    Result := LLockLst.Add(Value) > 0;
  finally
    FRetained.UnlockList;
  end;
end;

procedure TMQTTCustomServer.AddSession(const ASession: IMessageEvents);
begin
  SetLength(FSessions, Length(FSessions) + 1);
  FSessions[Length(FSessions) - 1] := ASession;
end;



function TMQTTCustomServer.DeleteRetainedMessage(
  const ATopic: UTF8String): Boolean;
var
  LLockLst: TList<IMessageItem>;
  LMessage: IMessageItem;
begin
  Result := False;
  LMessage := GetRetainedMessage(ATopic);
  if assigned(LMessage) then
  begin
    LLockLst := FRetained.LockList;
    try
      LLockLst.Remove(LMessage);
      LMessage := nil;
      Result := True;
    finally
      FRetained.UnlockList;
    end;
  end;
end;

procedure TMQTTCustomServer.SetWill(aTopic: UTF8String; aMessage: String; aQos: TMQTTQOSType;
  aRetain: boolean);
begin
  FWillMessage := TMessageItem.Create(0, aQos, aTopic, aMessage, aRetain);
  FWillFlag := (Length(aTopic) > 0) and (Length(aMessage) > 0);
end;

procedure TMQTTCustomServer.UpdateSessionHandler(const ASession: TMQTTSessionAdapter;
  const AHandler: TIdIOHandler);
var
  LIndex: Integer;
  LMsgEvnts: IMessageEvents;
  LSessioin: TMQttSession;
begin
 LIndex := GetSessionIndex(ASession.Session.ClientID);
 if LIndex >= 0 then
   if supports(FSessions[LIndex], IMessageEvents, LMsgEvnts) then
   begin
     LSessioin := TMQTTSessionAdapter(LMsgEvnts.GetImplementartor).Session;
     LSessioin.Handler := AHandler;
     ASession.Handler := AHandler;
   end;
end;

destructor TMQTTCustomServer.Destroy;
begin
  SetLength(FSessions, 0);
  FRetained.Free;
  inherited;
end;

procedure TMQTTCustomServer.DoLog(Sender: TObject; AString: String);
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

procedure TMQTTCustomServer.DoSessionNotify(Sender: TObject;
  const Item: TMQTTSessionAdapter; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

function TMQTTCustomServer.GetRetainedMessage(const ATopoc: UTF8String): IMessageItem;
var
  LLockLst: TList<IMessageItem>;
  LMessage: IMessageItem;
begin
  Result := nil;
  if not Assigned(FRetained) then
   FRetained := TThreadList<IMessageItem>.Create;
  LLockLst := FRetained.LockList;
  try
    for LMessage in LLockLst do
      if isAllowedTopic(LMessage.Topic, ATopoc) then
      begin
        Result := LMessage;
        Exit;
      end;
  finally
    FRetained.UnlockList;
  end;
end;

function TMQTTCustomServer.GetSesion(AHandler: TIdIOHandler): TMQTTSessionAdapter;
var
  LSession: IUnknown;
  LSessionAdapter: IMessageEvents;
begin
  Result := nil;
  for LSession in FSessions do
  begin
    if Supports(LSession, IMessageEvents, LSessionAdapter) and (LSessionAdapter <> nil) then
      if TMQTTSessionAdapter(LSessionAdapter.GetImplementartor).Handler = AHandler then
      begin
        Result := TMQTTSessionAdapter(LSessionAdapter.GetImplementartor);
        break;
      end;
  end;
end;

function TMQTTCustomServer.GetSession(
  AClientID: UTF8String): TMQTTSessionAdapter;
var
  LItem: IUnknown;
  LSessionAdapter: IMessageEvents;
begin
  Result := nil;
  for LItem in FSessions do
  begin
    if Supports(LItem, IMessageEvents, LSessionAdapter) and (LSessionAdapter <> nil) then
      if TMQTTSessionAdapter(LSessionAdapter.GetImplementartor).Session.ClientID = AClientID then
      begin
        Result := TMQTTSessionAdapter(LSessionAdapter.GetImplementartor);
        break;
      end;
  end;
end;

function TMQTTCustomServer.GetSessionIndex(AClientID: UTF8String): Integer;
var
  I: Integer;
   LSessionAdapter: IMessageEvents;
begin
  Result := -1;
  for I := 0 to High(FSessions) do
  begin
    if Supports(FSessions[I], IMessageEvents, LSessionAdapter) and (LSessionAdapter <> nil) then
      if TMQTTSessionAdapter(LSessionAdapter.GetImplementartor).Session.ClientID = AClientID then
        exit(I);
  end;
end;


procedure TMQTTCustomServer.DoDisconnect(AContext: TIdContext);
var
  LSession: TMQTTSessionAdapter;
begin
  LSession := GetSesion(AContext.Connection.IOHandler);
  if LSession <> nil then
  begin
    LSession.Session.Alive := False;
    MessagePublisher.MessageEvents - LSession;
    if LSession.Session.Clean then
      RemoveSession(GetSessionIndex(LSession.Session.ClientID));
  end;
end;


function TMQTTCustomServer.DoExecute(AContext: TIdContext): Boolean;
var
 LSession: TMQTTSessionAdapter;
 LLocalSessionAdapter: IMessageEvents;
 LBuffer: TIdBytes;
 LStrm: TMemoryStream;
 LMsgType: TMQTTMessageType;
 LDup: Boolean;
 LQoS: TMQTTQOSType;
 LRetain: Boolean;
 LProtocol, LClientID: UTF8String;
 LVersion: Byte;
 LKeepAlive: Word;
 LClean: Boolean;
  // under ARC, convert a weak reference to a strong reference before working with it
  LConn: TIdTCPConnection;
begin
  Result := False;
  if AContext <> nil then begin
    LConn := AContext.Connection;
    if LConn <> nil then begin
      Result := LConn.Connected;
    end;
  end;

  AContext.Connection.IOHandler.ReadTimeout := 500;
  AContext.Connection.IOHandler.ReadBytes(LBuffer, -1, False);
  if length(LBuffer) = 0 then exit;
  LStrm := TMemoryStream.Create;
  try
      LStrm.WriteData(LBuffer, length(LBuffer));
      LStrm.Position := 0;
      ReadHeader(LStrm, LMsgType, LDup, LQoS, LRetain);
      if LMsgType = mtCONNECT then
      begin
        if ReadConnection(LStrm, LProtocol, LClientID, LVersion, LKeepAlive, LClean) then
        begin
          LSession := GetSession(LClientID);
          if Assigned(LSession) then
          begin
            DoLog(LSession, UTF8ToString(LClientID)  + #9 +  'Session found.');
            if LSession.Session.Alive then
            begin
              DoLog(LSession, UTF8ToString(LClientID) + #9 + 'Get CONNECT comand when session alive. Disconnecting.');
              LSession.Session.Alive := False;
              AContext.Connection.Disconnect;
              exit;
            end else
            begin
              DoLog(LSession, UTF8ToString(LClientID) + #9 + 'Session  Reconnection.');
              UpdateSessionHandler(LSession, AContext.Connection.IOHandler);
//              LSession.Session.Handler := AContext.Connection.IOHandler;
              LSession.Session.Alive := True;
              MessagePublisher.MessageEvents + LSession;
            end;
          end else
          begin
            LLocalSessionAdapter := TMQTTSessionAdapter.Create(self, AContext.Connection.IOHandler);
            TMQTTSessionAdapter(LLocalSessionAdapter.GetImplementartor).Session.OnCheckUser := FOnCheckUser;
            TMQTTSessionAdapter(LLocalSessionAdapter.GetImplementartor).Session.OnLog := DoLog;
            AddSession(LLocalSessionAdapter);
            LSession := TMQTTSessionAdapter(LLocalSessionAdapter.GetImplementartor);
          end;
        end;
      end else
        LSession := GetSesion(AContext.Connection.IOHandler);
      if LSession <> nil then
      begin
        LStrm.Position := 0;
        LSession.Session.Execute(LStrm);
      end else
      begin
        DoLog(self, 'Session not found. Reject connection!');
        AContext.Connection.Disconnect;
      end;
  finally
    LStrm.Free;
  end;
//  inherited;
end;

procedure TMQTTCustomServer.OnStatus(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: string);
begin
  DOLog(self, AStatusText);
end;

procedure TMQTTCustomServer.RemoveSession(Index: Integer);
var
  LArrayLength: Integer;
begin
  LArrayLength := High(FSessions);
  if Index < LArrayLength then
  begin
    Finalize(FSessions[Index]);
    Move(FSessions[Index + 1], FSessions[Index],
      (LArrayLength - Index) * SizeOf(FSessions[Index]));
    SetLength(FSessions, LArrayLength);
  end;
end;



end.
