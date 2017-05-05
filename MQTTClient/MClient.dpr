program MClient;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main in 'Main.pas' {ClientMain},
  uTimer in '..\MQTT\src\uTimer.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TClientMain, ClientMain);
  Application.Run;
end.
