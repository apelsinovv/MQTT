unit Timer.Linux;

interface

uses
  Posix.Time,
  Linuxapi.Timerfd,
  Linuxapi.Epoll,
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections;

const
  INVALID_HANDLE_VALUE = THandle(-1);
  { EPoll consts }
  IGNORED = 1;

type
  TTimer = class(TObject)
    FHandle: THandle;
    FInternalHandle: THandle;
    FInterval: Cardinal;
    FOnTimer: TNotifyEvent;
  private
    FActive: Boolean;
    procedure SetActive(const Value: Boolean);
    procedure SetInterval(const Value: Cardinal);
  public
    constructor Create;
    destructor Destroy; override;
  public
    property Interval: Cardinal read FInterval write SetInterval;
    property OnTimer: TNotifyEvent read FOnTimer write FOnTimer;
    property Active: Boolean read FActive write SetActive;
  end;



implementation

uses
  Posix.Unistd,
  Posix.ErrNo;

{ TTimer }

constructor TTimer.Create;
var
 Event: epoll_event;
begin
  FActive := False;
  FHandle := epoll_create(IGNORED);
  if FHandle = -1 then
    raise Exception.Create(Format('epoll_create failed %s',[SysErrorMessage(errno)]));
  FInternalHandle := timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK);
  Event.data.ptr := Self;
  Event.events := EPOLLIN or EPOLLET;
  if epoll_ctl(FHandle, EPOLL_CTL_ADD, FInternalHandle, @Event) = -1 then
  begin
    __close(FInternalHandle);
     raise Exception.Create(Format('epoll_ctl failed %s',[SysErrorMessage(errno)]));
  end;
  Interval := 1000;
end;

destructor TTimer.Destroy;
begin
  if FInternalHandle <> -1 then
   __close(FInternalHandle);
  if FHandle <> -1 then
    __close(FHandle);
  inherited;
end;

procedure TTimer.SetActive(const Value: Boolean);
begin
  FActive := Value;
  if FActive then
  begin
    TThread.CreateAnonymousThread(
      procedure()
      var
        NumberOfEvents: Integer;
        I: Integer;
        Event: epoll_event;
        TotalTimeouts: Int64;
        Error: Integer;
      begin
        while FActive do
        begin
          try
            if __read(FInternalHandle, @TotalTimeouts, SizeOf(TotalTimeouts)) >= 0 then
            begin
              if Assigned(FOnTimer) then
                FOnTimer(Self);
            end;
          finally

          end;
        end;
      end
    ).Start;
  end;

end;

procedure TTimer.SetInterval(const Value: Cardinal);
var
  NewValue: itimerspec;
  TS: timespec;
  FStoreActive: Boolean;
begin
  FStoreActive := FActive;
  Active := False;

  FInterval := Value;
  FillChar(NewValue, SizeOf(itimerspec), 0);
  TS.tv_sec := FInterval DIV 1000;
  TS.tv_nsec := (FInterval MOD 1000) * 1000000;
  NewValue.it_value := TS;
  NewValue.it_interval := TS;
  if timerfd_settime(FInternalHandle, 0, @NewValue, nil) = -1 then
    Raise Exception.Create(Format('set_interval failed %s',[SysErrorMessage(errno)]));
  Active := FStoreActive;
end;

end.
