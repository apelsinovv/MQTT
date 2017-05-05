unit MQTTUtils;

interface
uses Classes, Types, SysUtils, StrUtils;

type
  TMQTTMessageType =
  (
//    mtReserved0,	  //  0	Reserved
    mtBROKERCONNECT,
    mtCONNECT,        //	1	Client request to connect to Broker
    mtCONNACK,        //	2	Connect Acknowledgment
    mtPUBLISH,        //	3	Publish message
    mtPUBACK,         //	4	Publish Acknowledgment
    mtPUBREC,         //	5	Publish Received (assured delivery part 1)
    mtPUBREL,         //	6	Publish Release (assured delivery part 2)
    mtPUBCOMP,        //	7	Publish Complete (assured delivery part 3)
    mtSUBSCRIBE,      //	8	Client Subscribe request
    mtSUBACK,         //	9	Subscribe Acknowledgment
    mtUNSUBSCRIBE,    // 10	Client Unsubscribe request
    mtUNSUBACK,       // 11	Unsubscribe Acknowledgment
    mtPINGREQ,        // 12	PING Request
    mtPINGRESP,       // 13	PING Response
    mtDISCONNECT,     // 14	Client is Disconnecting
    mtReserved15      // 15
  );

  TMQTTQOSType =
  (
    qtAT_MOST_ONCE,   //  0 At most once Fire and Forget        <=1
    qtAT_LEAST_ONCE,  //  1 At least once Acknowledged delivery >=1
    qtEXACTLY_ONCE,   //  2 Exactly once Assured delivery       =1
    qtReserved3,      //  3	Reserved
    qtFAILURE = $80   //  128 SUBACK code Filure
  );

  TMQTTPacket = class
    ID: Word;
    Stamp: TDateTime;
    Counter: cardinal;
    Retries: integer;
    Publishing: Boolean;
    Data: TMemoryStream;
    procedure Assign (AFrom: TMQTTPacket);
    constructor Create; overload;
    constructor Create(aID: Word; aMessage: TMemoryStream; aRetry: Integer; aCount: Cardinal); overload;

    destructor Destroy; override;
  end;

  procedure AddByte(aStream : TStream; aByte: Byte);
  procedure AddLength(aStream: TStream; aLen: integer);
  procedure AddString(aStream: TStream; aString: UTF8String);
  function ReadByte(aStream: TStream): Byte;
  function ReadLength(aStream: TStream): integer;
  function ReadString(aStream: TStream): UTF8String;
  procedure AddHeader(aStream: TStream; MsgType: TMQTTMessageType; Dup: Boolean = False;
    Qos: TMQTTQOSType = qtAT_MOST_ONCE; Retain: Boolean = False);
  function ReadHeader(aStream: TStream; out MsgType: TMQTTMessageType; out Dup: Boolean;
    out Qos: TMQTTQOSType; out Retain: Boolean) : byte;
  function ReadConnection(aStream: TStream; out aProtocol, aClientID: UTF8String; out aVersion: Byte; out aKeepAlive: Word; out aClean: Boolean): Boolean;

  function checkPublishTopic(const Topic: UTF8String): Boolean;
  function checkTopic(const Topic: UTF8String): Boolean;
  function isAllowedTopic(const MessageTopic, SubscribeTopic: UTF8String): Boolean;
  procedure SetDup(aStream: TMemoryStream; aState: boolean);

const
  MinVersion = 3;


  cNewConnection = 'New Connection from %s';
  cDIsconnect = 'Disconnected %s';


implementation
const
  cMaxTopicLength = 65535;


function checkPublishTopic(const Topic: UTF8String): Boolean;
var
  LStr, LTopic: String;
begin
  if (Topic = '') or (Length(Topic) > cMaxTopicLength) then
    Exit(False);
  LTopic := UTF8ToString(Topic);
  Result := FindDelimiter('#+$', LTopic) = 0;
end;

function checkTopic(const Topic: UTF8String): Boolean;
var
  LStr, LTopic: String;
begin
  if (Topic = '') or (Length(Topic) > cMaxTopicLength) then
    Exit(False);
  LTopic := UTF8ToString(Topic);
  for LStr in  SplitString(LTopic, '/') do
    if Length(LStr) > 1 then
      if ContainsStr(LStr, '#') or ContainsStr(LStr, '+') then
        Exit(False);
  Result := True;
end;

function isAllowedTopic(const MessageTopic, SubscribeTopic: UTF8String): Boolean;
var
  LMsgArray, LSubArray: TStringDynArray;
  LMsgStr, LSubStr: String;
  I: Integer;
begin
  Result := False;
  if not (checkTopic(MessageTopic) and checkTopic(SubscribeTopic)) then
    Exit;
  LMsgStr := UTF8ToString(MessageTopic);
  LSubStr := UTF8ToString(SubscribeTopic);
  LMsgArray := SplitString(LMsgStr, '/');
  LSubArray := SplitString(LSubStr, '/');
  for I := Low(LMsgArray) to High(LMsgArray) do
  begin
    if LSubArray[I] = '#' then
      Exit(True);
    if (LMsgArray[I] = LSubArray[I]) or (LMsgArray[I] = '+') then
    begin
      Result := True;
      continue;
    end else
      Exit(False);
  end;
end;

procedure SetDup(aStream: TMemoryStream; aState: boolean);
var
  x: byte;
begin
  if aStream.Size = 0 then exit;
  aStream.Seek(0, soFromBeginning);
  aStream.Read(x, 1);
  x := (x and $F7) or (ord (aState) * $08);
  aStream.Seek(0, soFromBeginning);
  aStream.Write(x, 1);
end;

procedure AddHeader(aStream: TStream; MsgType: TMQTTMessageType; Dup: Boolean = False;
  Qos: TMQTTQOSType = qtAT_MOST_ONCE; Retain: Boolean = False);
begin
  { Fixed Header Spec:
    bit	   |7 6	5	4	    | |3	     | |2	1	     |  |  0   |
    byte 1 |Message Type| |DUP flag| |QoS level|	|RETAIN| }
  AddByte (aStream, (Ord (MsgType) shl 4) + (ord (Dup) shl 3) + (ord (Qos) shl 1) + ord (Retain));
end;

procedure AddByte(aStream : TStream; aByte: Byte);
begin
  aStream.Write(aByte, 1);
end;

procedure AddLength(aStream: TStream; aLen: integer);
var
  x : integer;
  dig : byte;
begin
  x := aLen;
  repeat
    dig := x mod 128;
    x := x div 128;
    if (x > 0) then
      dig := dig or $80;
    AddByte(aStream, dig);
  until (x = 0);
end;

procedure AddString(aStream: TStream; aString: UTF8String);
var
  l: integer;
begin
  l := length(aString);
  AddByte(aStream, l div $100);
  AddByte(aStream, l mod $100);
  aStream.Write(aString[1], length(aString));
end;

function ReadHeader(aStream: TStream; out MsgType: TMQTTMessageType; out Dup: Boolean;
  out Qos: TMQTTQOSType; out Retain: Boolean) : byte;
begin
  Result := ReadByte (aStream);
  { Fixed Header Spec:
    bit	   |7 6	5	4	    | |3	     | |2	1	     |  |  0   |
    byte 1 |Message Type| |DUP flag| |QoS level|	|RETAIN| }
  MsgType := TMQTTMessageType((Result and $f0) shr 4);
  Dup := (Result and $08) > 0;
  Qos := TMQTTQOSType((Result and $06) shr 1);
  Retain := (Result and $01) > 0;
end;

function ReadByte(aStream: TStream): Byte;
begin
  if aStream.Position = aStream.Size then
    Result := 0
  else
    aStream.Read(Result, 1);
end;

function ReadLength(aStream: TStream): integer;
var
  mult: integer;
  x: byte;
begin
  mult := 0;
  Result := 0;
  repeat
    x := ReadByte(aStream);
    Result := Result + ((x and $7f) * mult);
  until (x and $80) <> 0;
end;

function ReadString(aStream: TStream): UTF8String;
var
  l: integer;
begin
  l:= ReadByte(aStream) * $100 + ReadByte(aStream);
  if aStream.Position + l <= aStream.Size then
    begin
      SetLength(Result, l);
      aStream.Read(Result[1], l);
    end;
end;

function ReadConnection(aStream: TStream; out aProtocol, aClientID: UTF8String; out aVersion: Byte; out aKeepAlive: Word; out aClean: Boolean): Boolean;
var
  LConnectionFlag,
  wq: Byte;
  wr, wf, un, ps: boolean;
begin
  Result := False;
  if assigned(aStream) then
  begin
    try
      aStream.Seek(LongInt(2), Word(soFromBeginning));
      aProtocol := ReadString(aStream); // protocol
      aVersion := ReadByte(aStream); // version
      LConnectionFlag := ReadByte(aStream);
      aKeepAlive := ReadByte(aStream) * $100 + ReadByte(aStream);
      aClientID := ReadString(aStream);
      wf := (LConnectionFlag and $04) > 0; // will flag
      wr := (LConnectionFlag and $10) > 0; // will retain
      wq := (LConnectionFlag and $18) shr 3; // will qos
      un := (LConnectionFlag and $80) > 0; // user name
      ps := (LConnectionFlag and $40) > 0; // pass word
      aClean := (LConnectionFlag and $02) > 0; // clean
      Result := True;
    except
      Result := False;
    end;
  end;
end;



{ TMQTTPacket }

procedure TMQTTPacket.Assign(AFrom: TMQTTPacket);
begin
  if assigned(AFrom) then
  begin
    ID := AFrom.ID;
    Stamp := AFrom.Stamp;
    Counter := AFrom.Counter;
    Retries := AFrom.Retries;
    Data.Clear;
    AFrom.Data.Seek (LongInt(0), soFromBeginning);
    Data.CopyFrom (AFrom.Data, AFrom.Data.Size);
    Publishing := AFrom.Publishing;
  end;
end;

constructor TMQTTPacket.Create;
begin
  ID := 0;
  Stamp := Now;
  Publishing := true;
  Counter := 0;
  Retries := 0;
  Data := TMemoryStream.Create;
end;

constructor TMQTTPacket.Create(aID: Word; aMessage: TMemoryStream; aRetry: Integer; aCount: Cardinal);
begin
  ID := aID;
  Stamp := Now;
  Publishing := true;
  Counter := aCount;
  Retries := aRetry;
  Data := TMemoryStream.Create;
  if assigned(aMessage) then
  begin
    aMessage.Seek(LongInt(0), soFromBeginning);
    Data.CopyFrom(aMessage, aMessage.Size);
  end;
end;

destructor TMQTTPacket.Destroy;
begin
  Data.Free;
  inherited;
end;

end.
