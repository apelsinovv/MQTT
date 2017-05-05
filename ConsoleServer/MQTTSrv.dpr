program MQTTSrv;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  MQTTServer,
  IdContext;

type
  TWrapper = class
    class var LogParam: String;
    class procedure DoheckUser(const aUserName, aPassword: UTF8String; var Allowed: Boolean);
    class procedure DoConnect(AContext: TIdContext);
    class procedure DoLog(sender: TObject; Astring: String);
  end;
var
   FMqttServer: TMQTTCustomServer;
{ TWrapper }

class procedure TWrapper.DoConnect(AContext: TIdContext);
begin
  WriteLN('Connect ' + AContext.Binding.IP);
end;

class procedure TWrapper.DoheckUser(const aUserName, aPassword: UTF8String;
  var Allowed: Boolean);
begin
  Allowed := true;
end;

class procedure TWrapper.DoLog(sender: TObject; Astring: String);
begin
 if CompareText(LogParam, '-v') = 0 then
   WriteLN(Astring);
end;

begin
  try
    if ParamCount > 0 then
     TWrapper.LogParam := ParamStr(1)
    else
     TWrapper.LogParam := '';

    FMqttServer := TMQTTCustomServer.Create(nil);
    FMqttServer.DefaultPort := 1883;
    FMqttServer.OnCheckUser := TWrapper.DoheckUser;
    FMqttServer.OnConnect := TWrapper.DoConnect;
    FMqttServer.OnLog := TWrapper.DoLog;
    FMqttServer.Active := True;

    while True do
      Sleep(30);
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
