unit KiSocketUnit;

interface

uses
  Winapi.Windows, Winapi.WinSock, System.Classes, System.SysUtils,
  System.AnsiStrings;

const
  CRLF         = #13#10;
  DefBufSize   = 1024 * 16;
  ShortBufSize = 512;

type
  TConnectionErrors = (not_sock = 10038, net_down = 10050, net_unreac = 10051,
    net_reset = 10052, conn_aborted = 10053, conn_reset = 10054, not_conn = 10057,
    timed_out = 10060, conn_refused = 10061, sysnot_ready = 10091);

  TSocketNotifyEvent = procedure(Sender: TObject) of Object;
  TSocketDataEvent = procedure(Sender: TObject; var Buf; var DataLen: integer) of Object;
  TSocketTextEvent = procedure(Sender: TObject; AText: string) of Object;
  TSocketErrorEvent = procedure(Sender: TObject; AError: string) of Object;

  TKiBaseSocket = class
  private
    procedure DoReceive(Buf: PAnsiChar; var DataLen: integer);
    procedure DoSend(Buf: PAnsiChar; var DataLen: integer);
    function GetConnected: boolean;
    function PeekBuf(var Buf; BufSize: Integer): integer;
    procedure SetIPAddress(Value: AnsiString);
    procedure SetPort(Value: Word);
    procedure SetBoundIP(Value: AnsiString);
    procedure SetBoundPort(Value: Word);
  protected
    FWSAData: TWSAData;
    FSocket: TSocket;
    FAddr: TSockAddr;
    FAddrBound: TSockAddr;
    FIPAddress: AnsiString;
    FPort: Word;
    FBoundIP: AnsiString;
    FBoundPort: Word;
    FOnError: TSocketErrorEvent;
    FOnCreateHandle: TSocketNotifyEvent;
    FOnDestroyHandle: TSocketNotifyEvent;
    FOnConnect: TSocketNotifyEvent;
    FOnDisconnect: TSocketNotifyEvent;
    FOnReceive: TSocketDataEvent;
    FOnSend: TSocketDataEvent;
    FNewSocket: boolean;
    procedure DoError;
    procedure DoWSAError;
    procedure DoCreateHandle;
    procedure DoDestroyHandle;
    procedure DoConnect;
    procedure DoDisconnect;
    function InternalConnect: boolean; virtual;
    function InternalDisconnect: boolean; virtual;
    property Connected: boolean read GetConnected;
    property BoundIP: AnsiString read FBoundIP write SetBoundIP;
    property BoundPort: Word read FBoundPort write SetBoundPort;
    property RemoteHost: AnsiString read FIPAddress write SetIPAddress;
    property RemotePort: Word read FPort write SetPort;
    property OnError: TSocketErrorEvent read FOnError write FOnError;
    property OnCreateHandle: TSocketNotifyEvent read FOnCreateHandle write FOnCreateHandle;
    property OnDestroyHandle: TSocketNotifyEvent read FOnDestroyHandle write FOnDestroyHandle;
    property OnConnect: TSocketNotifyEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TSocketNotifyEvent read FOnDisconnect write FOnDisconnect;
    property OnReceive: TSocketDataEvent read FOnReceive write FOnReceive;
    property OnSend: TSocketDataEvent read FOnSend write FOnSend;
  public
    constructor Create(AHostIP: AnsiString = ''; AHostPort: Word = 0); overload; virtual;
    constructor Create(ASocket: NativeInt; AHostIP: AnsiString = ''; AHostPort: Word = 0); overload; virtual;
    destructor Destroy; override;
    function Connect: boolean;
    function Disconnect: boolean;
    function SendBuf(var Buf; BufSize: Integer; Flags: Integer = 0): integer;
    function ReceiveBuf(var Buf; BufSize: Integer; Flags: Integer = 0): integer;
    function SendLn(AString: AnsiString; const eol: AnsiString = CRLF): integer;
    function ReceiveLn(const eol: AnsiString = CRLF): AnsiString;
    function ReceiveStream(StreamSize: integer): TStream;
    function SendStream(AStream: TStream): Integer;
  end;

  TKiClientSocket = class(TKiBaseSocket)
  public
    property Socket: TSocket read FSocket;
    property Connected;
    property BoundIP;
    property BoundPort;
    property RemoteHost;
    property RemotePort;
    property OnError;
    property OnCreateHandle;
    property OnDestroyHandle;
    property OnConnect;
    property OnDisconnect;
    property OnReceive;
    property OnSend;
  end;

implementation

{ TKiBaseSocket }

function TKiBaseSocket.Connect: boolean;
begin
  Result := False;
  if not InternalConnect then
    Exit;

  if FNewSocket then
  begin
    try
      if Winapi.WinSock.connect(FSocket, FAddr, SizeOf(FAddr)) <> 0 then
      begin
        DoWSAError;
        InternalDisconnect;
        Exit;
      end;
    except
      DoError;
      InternalDisconnect;
      Exit;
    end;
  end;

  if GetConnected then
  begin
    Result := True;
    DoConnect;
  end;
end;

constructor TKiBaseSocket.Create(AHostIP: AnsiString; AHostPort: Word);
begin
  FSocket := INVALID_SOCKET;
  FNewSocket := True;
  Create(FSocket, AHostIP, AHostPort);
end;

constructor TKiBaseSocket.Create(ASocket: NativeInt; AHostIP: AnsiString; AHostPort: Word);
begin
  if WSAStartup(MakeWord(2, 2), FWSAData) <> 0 then
    raise Exception.Create(SysErrorMessage(WSAGetLastError));

  FSocket := ASocket;
  FNewSocket := FSocket = INVALID_SOCKET;

  if AHostIP <> '' then
    SetIPAddress(AHostIP);
  if AHostPort <> 0 then
    SetPort(AHostPort);
end;

destructor TKiBaseSocket.Destroy;
begin

  inherited;
end;

function TKiBaseSocket.Disconnect: boolean;
begin
  Result := InternalDisconnect;
end;

procedure TKiBaseSocket.DoConnect;
begin
  if Assigned(FOnConnect) then
    FOnConnect(Self);
end;

procedure TKiBaseSocket.DoCreateHandle;
begin
  if Assigned(FOnCreateHandle) then
    FOnCreatehandle(Self);
end;

procedure TKiBaseSocket.DoDestroyHandle;
begin
  if Assigned(FOnDestroyHandle) then
    FOnDestroyHandle(Self);
end;

procedure TKiBaseSocket.DoDisconnect;
begin
  if Assigned(FOnDisconnect) then
    FOnDisconnect(Self);
end;

procedure TKiBaseSocket.DoError;
var
  N: Cardinal;
  S: string;
begin
  N := GetLastError;
  S := N.ToString + ': ' + SysErrorMessage(N);
  if Assigned(FOnError) then
    FOnError(Self, S)
  else
    raise Exception.Create(S);
end;

procedure TKiBaseSocket.DoReceive(Buf: PAnsiChar; var DataLen: integer);
begin
  if Assigned(FOnReceive) then
    FOnReceive(Self, Buf, DataLen);
end;

procedure TKiBaseSocket.DoSend(Buf: PAnsiChar; var DataLen: integer);
begin
  if Assigned(FOnSend) then
    FOnSend(Self, Buf, DataLen);
end;

procedure TKiBaseSocket.DoWSAError;
var
  N: Cardinal;
  S: string;
begin
  N := WSAGetLastError;
  S := N.ToString + ': ' + SysErrorMessage(N);
  if Assigned(FOnError) then
    FOnError(Self, S)
  else
    raise Exception.Create(S);
end;

function TKiBaseSocket.GetConnected: boolean;
begin
  Result := FSocket <> INVALID_SOCKET;
end;

function TKiBaseSocket.InternalConnect: boolean;
const
  TimeOut: integer = 20000;
begin
  Result := False;

  if FNewSocket then
  begin
    try
      FSocket := Winapi.WinSock.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    except
      DoError;
    end;
    if FSocket = INVALID_SOCKET then
    begin
      DoWSAError;
      Exit;
    end;
  end;

  DoCreateHandle;

  setsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, PAnsiChar(@TimeOut), SizeOf(TimeOut));
  setsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, PAnsiChar(@TimeOut), SizeOf(TimeOut));

  Result := True;
  {
  if Winapi.WinSock.bind(FSocket, FAddrBound, SizeOf(FAddrBound)) = SOCKET_ERROR then
  begin
    DoWSAError;
    InternalDisconnect;
    Exit;
  end;
  }

end;

function TKiBaseSocket.InternalDisconnect: boolean;
begin
  Result := False;

  if FSocket <> INVALID_SOCKET then
  try
    if shutdown(FSocket, SD_BOTH) = SOCKET_ERROR then
    //  DoDestroyHandle
    //else
      DoWSAError;
    if closesocket(FSocket) <> SOCKET_ERROR then
      DoDestroyHandle
    else
      DoWSAError;
    FSocket := INVALID_SOCKET;
  except
    DoError;
    Exit;
  end;

  Result := True;
  DoDisconnect;
end;

function TKiBaseSocket.PeekBuf(var Buf; BufSize: Integer): integer;
begin
  Result := recv(FSocket, Buf, BufSize, MSG_PEEK);
  if Result = SOCKET_ERROR then
    DoWSAError;
end;

function TKiBaseSocket.ReceiveBuf(var Buf; BufSize,
  Flags: Integer): integer;
begin
  Result := recv(FSocket, Buf, BufSize, Flags);
  if Result <> SOCKET_ERROR then
  begin
    if Result > 0 then
      DoReceive(PAnsiChar(@Buf), Result);
  end else
    DoWSAError;
end;

function TKiBaseSocket.ReceiveLn(const eol: AnsiString): AnsiString;
var
  len: Integer;
  buf: array[0..ShortBufSize - 1] of AnsiChar;
  eolptr: PAnsiChar;
begin
  Result := '';
  eolptr := nil;
  repeat
    len := PeekBuf(buf, sizeof(buf) - 1);
    if len > 0 then
    begin
      //if len > Length(buf) then
      //  SetLength(buf, len);
      buf[len] := #0;
      eolptr := System.AnsiStrings.StrPos(buf, PAnsiChar(eol));
      if eolptr <> nil then
        len := eolptr - buf + length(eol);
      ReceiveBuf(buf, len);
      if eolptr <> nil then
        len := len - length(eol);
      buf[len] := #0;
      Result := Result + buf;
    end;
  until (len < 1) or (eolptr <> nil);
end;

function TKiBaseSocket.ReceiveStream(StreamSize: integer): TStream;
var
  Total: integer;
  Res: integer;
  Buf: array[0..ShortBufSize - 1] of Byte;
begin
  Result := TStringStream.Create;
  Result.Seek(0, TSeekOrigin.soBeginning);
  Total := 0;

  repeat
    Res := ReceiveBuf(Buf, Length(Buf), 0);

    if Res <= 0 then
      Break;

    Result.WriteBuffer(Buf[0], Res);
    Inc(Total, Res);
  until Total >= StreamSize;
end;

function TKiBaseSocket.SendBuf(var Buf; BufSize, Flags: Integer): integer;
begin
  try
    if BufSize <= 0 then
      raise Exception.Create('Empty buffer to send');

    Result := send(FSocket, Buf, BufSize, Flags);
    if Result = SOCKET_ERROR then
    begin
      DoWSAError;
      Exit;
    end else
    begin
      DoSend(PAnsiChar(@Buf), Result);
    end;

  except
    DoError;
  end;
end;

function TKiBaseSocket.SendLn(AString: AnsiString;
  const eol: AnsiString): integer;
begin
  Result := SOCKET_ERROR;
  try
    if Length(AString) = 0 then
      raise Exception.Create('Empty string to send.');

    AString := AString + eol;
    Result := SendBuf(PAnsiChar(AString)^, Length(AString), 0);
  except
    DoError;
  end;
end;

function TKiBaseSocket.SendStream(AStream: TStream): Integer;
var
  BufLen: integer;
  Buffer: array[0..ShortBufSize - 1] of Byte;
begin
  Result := 0;
  if Assigned(AStream) then
  try

    BufLen := AStream.Size;
    if BufLen = 0 then
      raise Exception.Create('Empty stream to send.');

    repeat
      BufLen := AStream.Read(Buffer, Length(Buffer));
    until (BufLen = 0) or (SendBuf(Buffer, BufLen) = SOCKET_ERROR);
  except
    DoError;
  end;
end;

procedure TKiBaseSocket.SetBoundIP(Value: AnsiString);
begin
  if Value = '' then
    raise Exception.Create('BoundIP Address can''t be empty.');

  if not System.AnsiStrings.SameText(FIPAddress, Value) then
  try
    FillChar(FAddrBound.sin_zero, SizeOf(FAddrBound.sin_zero), 0);
    FAddrBound.sin_family := AF_INET;
    FAddrBound.sin_addr.S_addr := inet_addr(PAnsiChar(Value));
  except
    DoError;
  end;
  if FAddrBound.sin_addr.S_addr = Integer(INADDR_NONE) then
    raise Exception.Create('BoundIP Address input syntax error.');
  FBoundIP := Value;
end;

procedure TKiBaseSocket.SetBoundPort(Value: Word);
begin
  if Value = 0 then
    raise Exception.Create('BoundPort value can''t be 0.');

  if FPort <> Value then
  try
    FAddrBound.sin_port := htons(Value);
    FBoundPort := Value;
  except
    DoError;
  end;
end;

procedure TKiBaseSocket.SetIPAddress(Value: AnsiString);
begin
  if Value = '' then
    raise Exception.Create('IP Address can''t be empty.');

  if not System.AnsiStrings.SameText(FIPAddress, Value) then
  try
    FillChar(FAddr.sin_zero, SizeOf(FAddr.sin_zero), 0);
    FAddr.sin_family := AF_INET;
    FAddr.sin_addr.S_addr := inet_addr(PAnsiChar(Value));
  except
    DoError;
  end;
  if FAddr.sin_addr.S_addr = Integer(INADDR_NONE) then
    raise Exception.Create('IP Address input syntax error.');
  FIPAddress := Value;
end;

procedure TKiBaseSocket.SetPort(Value: Word);
begin
  if Value = 0 then
    raise Exception.Create('Port value can''t be 0.');

  if FPort <> Value then
  try
    FAddr.sin_port := htons(Value);
    FPort := Value;
  except
    DoError;
  end;
end;

end.
