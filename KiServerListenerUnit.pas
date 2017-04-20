unit KiServerListenerUnit;

interface

uses
  Winapi.WinSock, System.Classes, System.SysUtils, System.AnsiStrings,
  KiSocketUnit, KiServerClientThreadUnit;

type
  TKiServerListener = class(TThread)
  private
    FServerSocket: TSocket;
    FLogMsg: string;
    FOnLog: TSocketTextEvent;
    FOnStartListen: TSocketNotifyEvent;
    FOnStopListen: TSocketNotifyEvent;
    FStop: boolean;
    FObj: TObject;
    procedure DoStartListen;
    procedure DoStopListen;
    procedure DoLog;
    procedure LogMsg(Msg: string);
    procedure StartListen;
    procedure StopListen;
  protected
    procedure Execute; override;
  public
    constructor Create(AServerSocket: TSocket; AServer: TObject);
    destructor Destroy; override;
    procedure Stop;
    property OnLog: TSocketTextEvent read FOnLog write FOnLog;
    property OnStartListen: TSocketNotifyEvent read FOnStartListen write FOnStartListen;
    property OnStopListen: TSocketNotifyEvent read FOnStopListen write FOnStopListen;
  end;

implementation

{ TKiServerListener }

uses KiServerSocketUnit;

constructor TKiServerListener.Create(AServerSocket: TSocket; AServer: TObject);
begin
  FServerSocket := AServerSocket;
  FObj := AServer;
  FreeOnTerminate := True;
  inherited Create(True);
end;

destructor TKiServerListener.Destroy;
begin

  inherited;
end;

procedure TKiServerListener.DoLog;
begin
  if Assigned(FOnlog) then
    FOnLog(Self, FLogMsg);
end;

procedure TKiServerListener.DoStartListen;
begin
  if Assigned(FOnStartListen) then
    FOnStartListen(Self);
end;

procedure TKiServerListener.DoStopListen;
begin
  if Assigned(FOnStopListen) then
    FOnStopListen(Self);
end;

procedure TKiServerListener.Execute;
var
  LSocket: TSocket;
  ClientAddr: TSockAddr;
  ClientAddrLen: integer;
  ClientThread: TKiServerClientThread;
  FServer: TKiServerSocket;
begin
  StartListen;
  FStop := False;
  FServer := TKiServerSocket(FObj);
  while not Terminated do
  begin
    if FStop then
      Break;
    Sleep(10);

    ClientAddrLen := SizeOf(ClientAddr);
    LSocket := accept(FServerSocket, @ClientAddr, @ClientAddrLen);
    if LSocket = INVALID_SOCKET then
    begin
      LogMsg(SysErrorMessage(WSAGetLastError));
      Break;
    end;

    ClientThread := TKiServerClientThread.Create(LSocket,
      System.AnsiStrings.StrPas(inet_ntoa(ClientAddr.sin_addr)), ntohs(ClientAddr.sin_port));
    {$WARN SYMBOL_PLATFORM OFF}
    ClientThread.Priority := TThreadPriority.tpLowest;
    {$WARN SYMBOL_PLATFORM ON}
    ClientThread.ClientLog := FServer.OnClientLog;
    ClientThread.OnTerminate := FServer.ClientThreadTerminate;
    FServer.AddClientThread(ClientThread);
    ClientThread.Start;

  end;
  StopListen;
end;

procedure TKiServerListener.LogMsg(Msg: string);
begin
  FLogMsg := Msg;
  Synchronize(DoLog);
end;

procedure TKiServerListener.StartListen;
begin
  Synchronize(DoStartListen);
end;

procedure TKiServerListener.Stop;
begin
  FStop := True;
end;

procedure TKiServerListener.StopListen;
begin
  Synchronize(DoStopListen);
end;

end.
