unit uTimer;

interface
uses
  System.Types, SysUtils, Classes, Threading;

type
  TTimer = class
  private
    FActive: Boolean;
    FInterval: Cardinal;
    FOnTimer: TNotifyEvent;
    procedure SetActive(const Value: Boolean);
    procedure SetInterval(const Value: Cardinal);
  public
    constructor Create;
  public
    property Interval: Cardinal read FInterval write SetInterval;
    property OnTimer: TNotifyEvent read FOnTimer write FOnTimer;
    property Active: Boolean read FActive write SetActive;
  end;
implementation

{ TTimer }

constructor TTimer.Create;
begin
  FInterval := 1000;
end;

procedure TTimer.SetActive(const Value: Boolean);
begin
  FActive := Value;
  if FActive then
  begin
    TTask.Run(
      procedure()
      begin
       while FActive do
       begin
         sleep(FInterval);
         TThread.Synchronize(nil,
           procedure()
           begin
             if assigned(FOnTimer) then FOnTimer(self);
           end);
       end;
      end);
  end
end;

procedure TTimer.SetInterval(const Value: Cardinal);
begin
  FInterval := Value;
end;

end.
