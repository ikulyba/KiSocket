unit KiServerSocketUnit;

interface

uses
  Winapi.Windows, Winapi.WinSock, System.Classes, System.SysUtils, System.Types,
  System.AnsiStrings, KiSocketUnit, KiServerListenerUnit, KiServerClientThreadUnit;

type
  TKiServerSocket = class(TKiBaseSocket)
  private
    FListener: TKiServerListener;
    FClientsList: TThreadList;
    FClientsCount: integer;
    FOnStart: TSocketNotifyEvent;
    FOnStop: TSocketNotifyEvent;
    FOnLog: TSocketTextEvent;
    FOnStartListen: TSocketNotifyEvent;
    FOnStopListen: TSocketNotifyEvent;
    FOnLogListen: TSocketTextEvent;
    FOnClientLog: TSocketTextEvent;
    function GetActive: boolean;
    function GetClientsCount: integer;
    procedure DoStart;
    procedure DoStop;
    //procedure DoLog(S: string);
    //procedure DoLogListen(S: string);
    procedure ListenerDone(Sender: TObject);
  protected
    function InternalConnect: boolean; override;
    function InternalDisconnect: boolean; override;
  public
    constructor Create(AHostIP: AnsiString = ''; AHostPort: Word = 0); override;
    destructor Destroy; override;
    function Start: boolean;
    function Stop: boolean;
    procedure AddClientThread(ClientThread: TKiServerClientThread);
    procedure RemoveClientThread(ClientThread: TKiServerClientThread);
    procedure ClientThreadTerminate(Sender: TObject);
    property Active: boolean read GetActive;
    property ClientsCount: integer read GetClientsCount;
    property Listener: TKiServerListener read FListener;
    property OnCreateHandle;
    property OnDestroyHandle;
    property OnError;
    property OnStart: TSocketNotifyEvent read FOnStart write FOnStart;
    property OnStop: TSocketNotifyEvent read FOnSTop write FOnStop;
    property OnLog: TSocketTextEvent read FOnLog write FOnLog;
    property OnStatListen: TSocketNotifyEvent read FOnStartListen write FOnStartListen;
    property OnStopListen: TSocketNotifyEvent read FOnStopListen write FOnStopListen;
    property OnLogListen: TSocketTextEvent read FOnLogListen write FOnLogListen;
    property OnClientLog: TSocketTextEvent read FOnClientLog write FOnClientLog;
  end;

implementation

{ TKiServerSocket }


{ TKiServerSocket }

procedure TKiServerSocket.AddClientThread(ClientThread: TKiServerClientThread);
begin
  with FClientsList.LockList do
  try
    Add(ClientThread);
    FClientsCount := Count;
  finally
    FClientsList.UnlockList;
  end;
end;

procedure TKiServerSocket.ClientThreadTerminate(Sender: TObject);
begin
  RemoveClientThread(TKiServerClientThread(Sender));
end;

constructor TKiServerSocket.Create(AHostIP: AnsiString; AHostPort: Word);
begin
  inherited Create(AHostIP, AHostPort);
  FListener := nil;
  FClientsList := TThreadList.Create;
  FClientsCount := 0;
end;

destructor TKiServerSocket.Destroy;
begin
  FClientsList.Free;
  inherited;
end;
{
procedure TKiServerSocket.DoLog(S: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, S);
end;

procedure TKiServerSocket.DoLogListen(S: string);
begin
  if Assigned(FOnLogListen) then
    FOnLogListen(Self, S);
end;
}
procedure TKiServerSocket.DoStart;
begin
  if Assigned(FOnStart) then
    FOnStart(Self);
end;

procedure TKiServerSocket.DoStop;
begin
  if Assigned(FOnStop) then
    FOnStop(Self);
end;

function TKiServerSocket.GetActive: boolean;
begin
  Result := (FSocket <> INVALID_SOCKET) and (FListener <> nil);
end;

function TKiServerSocket.GetClientsCount: integer;
begin
  Result := FClientsCount;
end;

function TKiServerSocket.InternalConnect: boolean;
begin
  Result := False;
  if not inherited InternalConnect then
    Exit;

  try
    if bind(FSocket, FAddr, SizeOf(FAddr)) = SOCKET_ERROR then
    begin
      DoWSAError;
      InternalDisconnect;
      Exit;
    end;
  except
    begin
      DoError;
      InternalDisconnect;
      Exit;
    end;
  end;

  try
    if listen(FSocket, SOMAXCONN) = SOCKET_ERROR then
    begin
      DoWSAError;
      InternalDisconnect;
      Exit;
    end;
  except
    begin
      DoError;
      InternalDisconnect;
      Exit;
    end;
  end;

  FListener := TKiServerListener.Create(FSocket, Self);
  {$WARN SYMBOL_PLATFORM OFF}
  FListener.Priority := TThreadPriority.tpLowest;
  {$WARN SYMBOL_PLATFORM ON}
  FListener.OnStartListen := FOnStartListen;
  FListener.OnStopListen := FOnStopListen;
  FListener.OnTerminate := ListenerDone;
  FListener.Start;

  Result := True;
  DoStart;
end;

function TKiServerSocket.InternalDisconnect: boolean;
begin
  Result := False;
  if not inherited InternalDisconnect then
    Exit;

  Result := True;
  DoStop;
end;

procedure TKiServerSocket.ListenerDone(Sender: TObject);
begin
  FListener := nil;
end;

procedure TKiServerSocket.RemoveClientThread(
  ClientThread: TKiServerClientThread);
var
  I, N: integer;
begin
  I := 0;
  N := -1;

  with FClientsList.LockList do
  try
    while I < Count do
    begin
      if TKiServerClientThread(Items[I]) = ClientThread then
      begin
        N := I;
        Break;
      end;
      Inc(I);
    end;

    if N <> -1 then
    begin
      Remove(ClientThread);
    end;

    FClientsCount := Count;
  finally
    FClientsList.UnlockList;
  end;
end;

function TKiServerSocket.Start: boolean;
begin
  if GetActive then
    raise Exception.Create('Server is already running.');

  Result := InternalConnect;
end;

function TKiServerSocket.Stop: boolean;
begin
  Result := InternalDisconnect;
end;

end.
