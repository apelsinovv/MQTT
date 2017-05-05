unit Timer.Windows;

interface

uses
  Winapi.Windows, System.Types, SysUtils, Classes;

type
  TTimer = class
  private
    FActive: Boolean;
    Fthreaded: Boolean;
    FidTimer: Uint;
    FInterval: Cardinal;
    class var FOnTimer: TNotifyEvent;
    procedure SetActive(const Value: Boolean);
    procedure SetInterval(const Value: Cardinal);
    procedure InternalSetTimer;
  public
    constructor Create;
    destructor Destroy; override;
  public
    property Threaded: Boolean read Fthreaded write Fthreaded;
    property Interval: Cardinal read FInterval write SetInterval;
    class property OnTimer: TNotifyEvent read FOnTimer write FOnTimer;
    property Active: Boolean read FActive write SetActive;
  end;

implementation

procedure TimerProc(wnd: HWND; Msg: UINT; idEvent: UINT; Time: DWORD); stdcall;
begin
  if assigned(TTimer.FOnTimer) then
     TTimer.FOnTimer(nil);
end;
{ TTimer }

constructor TTimer.Create;
begin
  FidTimer := 0;
  FInterval := 1000;
end;

destructor TTimer.Destroy;
begin
  if FidTimer > 0 then
    KillTimer(0, FidTimer);
  inherited;
end;

procedure TTimer.InternalSetTimer;
begin
  try
    FidTimer := SetTimer(0, integer(self), FInterval, @TimerProc);
    if FidTimer = 0 then
    begin
      FActive := False;
      raise Exception.Create(Format('timer_create failed %d',[GetLastError]));
    end;
  finally
  end;
end;

procedure TTimer.SetActive(const Value: Boolean);
var
 msg: Tmsg;
begin
  FActive := Value;
  if FActive then
  begin
    if not Fthreaded then
      InternalSetTimer;
    TThread.CreateAnonymousThread(
      procedure()
      begin
        if Fthreaded then
        InternalSetTimer;
        while (GetMessage(Msg,0,0,0)) and FActive do DispatchMessage(Msg);
//        while FActive do
  //      begin
//          sleep(10);
//          DispatchMessage(WM_TIMER);
//        end;
      end
    ).Start;
  end else
  begin
    if FidTimer > 0 then
      KillTimer(0, FidTimer);
  end;
end;

procedure TTimer.SetInterval(const Value: Cardinal);
var
 LActive: Boolean;
begin
  LActive := FActive;
  Active := False;
  FInterval := Value;
  Active := LActive;
end;

end.
