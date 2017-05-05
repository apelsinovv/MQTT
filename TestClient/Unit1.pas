unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.ListBox, FMX.Layouts,
  FMX.ListView, MQTTClient, FMX.Edit, MQTTUtils, Threading, windows;

type
  TForm1 = class(TForm)
    ListView1: TListView;
    Layout1: TLayout;
    ListBox1: TListBox;
    ListBoxHeader1: TListBoxHeader;
    Button1: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    Button2: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Button3: TButton;
    CheckBox3: TCheckBox;
    Edit3: TEdit;
    ComboBox1: TComboBox;
    Button4: TButton;
    CheckBox4: TCheckBox;
    Edit4: TEdit;
    ComboBox2: TComboBox;
    Edit5: TEdit;
    CheckBox5: TCheckBox;
    Button5: TButton;
    Edit6: TEdit;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  private
    MQTTClient: TMQTTCustomClient;
    procedure OnReceive(Sender: TObject; anID: Word;
      aTopic: UTF8String; aMessage: String);
     procedure OnSubscribed(Sender: TObject);
     procedure OnConnect(Sender: TObject; code: Byte);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}



{
 LItem := lvMovies.Items.Add;
        LItem.Tag := dataset.FieldByName('id').AsInteger;
        LItem.Objects.TextObject.Text := dataset.FieldByName('caption').AsString;
        LItem.Objects.DetailObject.Text := dataset.FieldByName('short_description').AsString;
}
procedure TForm1.Button1Click(Sender: TObject);
begin
  MQTTClient.ClientID := Edit6.Text;
  MQTTClient.Host := Edit1.Text;
  MQTTClient.Port := Edit2.Text.ToInteger;
  MQTTClient.Username := 'User';
  MQTTClient.Password := 'User';
  MQTTClient.CleanSession := CheckBox1.IsChecked;
  MQTTClient.AutoSubscribe := CheckBox2.IsChecked;
  MQTTClient.OnSubscribed := OnSubscribed;
  MQTTClient.OnUnSubscribed := OnSubscribed;
  MQTTClient.OnReceivedMessage := OnReceive;
  MQTTClient.OnConnected := OnConnect;
  MQTTClient.Connect;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  MQTTClient.Disconnect;
  Button2.Enabled := False;
  Button1.Enabled := True;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
 MQTTClient.Session.Subscribe(UTF8Encode(Edit3.Text), TMQTTQOSType(ComboBox1.ItemIndex));
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
 if CheckBox4.IsChecked then
 begin
   TTask.Run(procedure()
   var
    Lidx: integer;
   begin
     Lidx := 0;
     while CheckBox4.IsChecked do
     begin
       MQTTClient.Session.Publish(UTF8Encode(Edit4.Text), Edit5.Text + ' ' + (Lidx mod 3).ToString, TMQTTQOSType(ComboBox1.ItemIndex mod 3), CheckBox5.IsChecked);
       inc(Lidx);
     end;
   end);
 end else
   MQTTClient.Session.Publish(UTF8Encode(Edit4.Text), Edit5.Text, TMQTTQOSType(ComboBox1.ItemIndex), CheckBox5.IsChecked);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  winexec('F:\projects\net_technology\mqtt\ConsoleServer\Win32\Debug\MQTTSrv.exe -v', SW_SHOW);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  MQTTClient := TMQTTCustomClient.Create(self);
end;

procedure TForm1.OnConnect(Sender: TObject; code: Byte);
begin
  if code = 0 then
  begin
    Button2.Enabled := True;
    Button1.Enabled := False;
  end;
end;

procedure TForm1.OnReceive(Sender: TObject; anID: Word; aTopic: UTF8String;
  aMessage: String);
var
  LItem: TListViewItem;
begin
  LItem := ListView1.Items.Add;
  LItem.Tag := anID;
  LItem.Objects.TextObject.Text := aMessage;
  LItem.Objects.DetailObject.Text := aTopic;
end;

procedure TForm1.OnSubscribed(Sender: TObject);
var
  item: String;
begin
  ListBox1.Items.Clear;
  for item in MQTTClient.Session.Subscriptions.Keys do
    ListBox1.Items.Add(item);
end;

end.
