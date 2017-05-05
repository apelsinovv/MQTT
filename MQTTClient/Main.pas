unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Forms, FMX.Dialogs, FMX.TabControl, System.Actions, FMX.ActnList,
  FMX.Objects, FMX.StdCtrls, FMX.ListBox, FMX.Layouts, FMX.ScrollBox, FMX.Memo,
  FMX.Edit, FMX.Controls.Presentation, MQTTClient;

type
  TClientMain = class(TForm)
    ActionList1: TActionList;
    PreviousTabAction1: TPreviousTabAction;
    TitleAction: TControlAction;
    NextTabAction1: TNextTabAction;
    TopToolBar: TToolBar;
    btnBack: TSpeedButton;
    ToolBarLabel: TLabel;
    btnNext: TSpeedButton;
    TabControl1: TTabControl;
    TabItem1: TTabItem;
    TabItem2: TTabItem;
    BottomToolBar: TToolBar;
    VertScrollBox1: TVertScrollBox;
    Layout1: TLayout;
    edConnectionName: TEdit;
    edHost: TEdit;
    edPort: TEdit;
    edClientID: TEdit;
    EditButton1: TEditButton;
    Label5: TLabel;
    Edit1: TEdit;
    chAutoconnect: TCheckBox;
    chCleanSession: TCheckBox;
    Expander1: TExpander;
    edUsername: TEdit;
    Label6: TLabel;
    Label7: TLabel;
    edPassword: TEdit;
    Expander2: TExpander;
    edWillTopic: TEdit;
    Label9: TLabel;
    edWillMessage: TMemo;
    cbWillQoS: TComboBox;
    Label10: TLabel;
    chWillRetain: TCheckBox;
    VertScrollBox2: TVertScrollBox;
    Expander3: TExpander;
    edSubTopic: TEdit;
    chSubQoS: TComboBox;
    CornerButton2: TCornerButton;
    lstSubscriptions: TListBox;
    Label16: TLabel;
    btnUnSubscribe: TCornerButton;
    Layout2: TLayout;
    Label12: TLabel;
    edTopic: TEdit;
    edMessage: TMemo;
    cbQoS: TComboBox;
    CornerButton1: TCornerButton;
    swRetain: TSwitch;
    Label15: TLabel;
    ListBox1: TListBox;
    ListBoxGroupHeader2: TListBoxGroupHeader;
    CornerButton3: TCornerButton;
    Label11: TLabel;
    Layout3: TLayout;
    Layout4: TLayout;
    Layout5: TLayout;
    Label1: TLabel;
    Layout6: TLayout;
    Label2: TLabel;
    Layout7: TLayout;
    Label3: TLabel;
    Label4: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure TitleActionUpdate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure Expander1ExpandedChanged(Sender: TObject);
    procedure Expander2ExpandedChanged(Sender: TObject);
    procedure Expander3ExpandedChanged(Sender: TObject);
    procedure CornerButton3Click(Sender: TObject);
    procedure CornerButton1Click(Sender: TObject);
    procedure CornerButton2Click(Sender: TObject);
    procedure EditButton1Click(Sender: TObject);
  private
    client: TMQTTCustomClient;
    procedure OnReceive(Sender: TObject; anID: Word;
      aTopic: UTF8String; aMessage: String);
    procedure OnSubscribed(Sender: TObject);
    procedure OnConnect(Sender: TObject; code: Byte);

  public
    { Public declarations }
  end;

var
  ClientMain: TClientMain;

implementation

uses MQTTUtils, MQTTSession;
{$R *.fmx}
{$R *.LgXhdpiPh.fmx ANDROID}
{$R *.iPhone4in.fmx IOS}

procedure TClientMain.TitleActionUpdate(Sender: TObject);
begin
  if Sender is TCustomAction then
  begin
    if TabControl1.ActiveTab <> nil then
      TCustomAction(Sender).Text := TabControl1.ActiveTab.Text
    else
      TCustomAction(Sender).Text := '';
  end;
end;

procedure TClientMain.CornerButton1Click(Sender: TObject);
begin
  if assigned( Client.Session) then
    Client.Session.Publish(edTopic.Text, edMessage.Text, TMQTTQosType(cbQoS.ItemIndex), swRetain.IsChecked);
end;

procedure TClientMain.CornerButton2Click(Sender: TObject);
begin
 if assigned(Client.Session) then
  Client.Session.Subscribe(edSubTopic.Text, TMQTTQosType(chSubQoS.ItemIndex));
end;

procedure TClientMain.CornerButton3Click(Sender: TObject);
begin
 if not client.Connected then
 begin
  client.Host := edHost.Text;
  client.Port := edPort.Text.ToInteger;
  client.ClientID := edClientID.Text;
  client.Username := edUsername.Text;
  client.Password := edPassword.Text;
  client.CleanSession := chCleanSession.IsChecked;
  client.OnSubscribed := OnSubscribed;
  client.OnUnSubscribed := OnSubscribed;
  client.OnReceivedMessage := OnReceive;
  client.OnConnected := OnConnect;
  client.Connect;
 end else
   Client.Disconnect;
end;

procedure TClientMain.EditButton1Click(Sender: TObject);
const
  s = 'abcdefghijklmnopqrstuvwxyz';
var
  i:integer;
begin
  for i:=1 TO 10 DO
    edClientID.Text := edClientID.Text + s[random(length(s)+1)+1];
end;

procedure TClientMain.Expander1ExpandedChanged(Sender: TObject);
begin
  Expander1.Height := 134;
end;

procedure TClientMain.Expander2ExpandedChanged(Sender: TObject);
begin
  Expander2.Height := 189;
end;

procedure TClientMain.Expander3ExpandedChanged(Sender: TObject);
begin
  Expander3.Height := 285;
end;

procedure TClientMain.FormCreate(Sender: TObject);
begin
  { This defines the default active tab at runtime }
    TabControl1.TabPosition := TTabPosition.None;
  TabControl1.First(TTabTransition.None);
  TabControl1.Next;
  client := TMQTTCustomClient.Create(self);
  EditButton1Click(self);
end;

procedure TClientMain.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if (Key = vkHardwareBack) and (TabControl1.TabIndex <> 0) then
  begin
    TabControl1.First;
    Key := 0;
  end;
end;

procedure TClientMain.OnConnect(Sender: TObject; code: Byte);
begin
 if code = 0 then
 begin
  if client.Connected and (edWillTopic.Text <> '') and (edWillMessage.Text <> '') then
    client.SetWill(edWillTopic.Text, edWillMessage.Text, TMQTTQosType(cbWillQoS.ItemIndex), chWillRetain.IsChecked);
  TabControl1.Next;
 end else
   Label11.Text := 'Error connection Code ' + Code.ToString;
end;

procedure TClientMain.OnReceive(Sender: TObject; anID: Word; aTopic: UTF8String;
  aMessage: String);
begin
  ListBox1.Items.AddPair(aTopic, aMessage);
end;

procedure TClientMain.OnSubscribed(Sender: TObject);
var
  LStr: UTF8String;
begin
  lstSubscriptions.Clear;
  for LStr in TMQTTClientSession(Sender).Subscriptions.Keys do
    lstSubscriptions.Items.Add(UTF8ToString(LStr));
end;

end.
