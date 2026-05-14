' =============================================================================
' vt_net.bas -- opt-in TCP/UDP (Winsock2 on Windows, POSIX on Linux) for libvt
' =============================================================================
#Ifdef __FB_WIN32__
    #Undef Integer
    #Define Integer Long
    #Include Once "win/winsock2.bi"
    Type SOCKET_T As Long
#Else
    #Include Once "crt.bi"
    #Include Once "crt/sys/select.bi"
    #Include Once "crt/sys/socket.bi"
    #Include Once "crt/netinet/in.bi"
    #Include Once "crt/netdb.bi"
    #Include Once "crt/unistd.bi"
    #Include Once "crt/arpa/inet.bi"

    #Define SOL_TCP         IPPROTO_TCP

    #Ifndef FIONBIO
        #Define FIONBIO     &h5421
    #Endif
    #Ifndef ioctl
        Declare Function ioctl Cdecl Alias "ioctl" (d As Long, request As Long, ...) As Long
    #Endif
    #Ifndef TCP_NODELAY
        Const TCP_NODELAY = &h0001
    #Endif
    #Ifndef INVALID_SOCKET
        #Define INVALID_SOCKET Cuint(-1)
    #Endif
    #Ifndef SOCKET_ERROR
        #Define SOCKET_ERROR -1
    #Endif

    Type SOCKET_T As Long
#Endif

' -----------------------------------------------------------------------------
' vt_net_init -- initialise networking subsystem
' Must be called once before any other vt_net function.
' On Linux this is a no-op (POSIX sockets need no init).
' Returns 0 on success, -1 on failure.
' -----------------------------------------------------------------------------
#Ifdef __FB_WIN32__
    '>>>
    ':topic vt_net_init
    ':short Initialise the networking subsystem (opt-in)
    ':group Networking
    'Initialise the networking subsystem. 
    'vt_net_init must be called once
    'before any other vt_net_* function.
    'Opt-in: define VT_USE_NET before the include.
    ':syntax
    Function vt_net_init() As Long
            ':notes
            'Return (vt_net_init):
            '   0  success
            '  -1  Winsock initialisation failed (Windows)
            ':example
            '#Define VT_USE_NET
            '#include once "vt/vt.bi"
            '
            'vt_screen(VT_SCREEN_0)
            'If vt_net_init() <> 0 Then
            '    vt_print("Network init failed." & VT_LF)
            '    vt_shutdown()
            'End If
            '' ... program ...
            'vt_net_shutdown()
            ':see
            'vt_net_open
            'vt_net_connect
        '<<<
        Dim wsa As WSAData
        If WSAStartup(MAKEWORD(2, 0), @wsa) <> 0 Then Return -1
        If wsa.wVersion <> MAKEWORD(2, 0) Then WSACleanup() : Return -1
        Return 0
    End Function
#Else
    Function vt_net_init() As Long
        Return 0
    End Function
#Endif

' -----------------------------------------------------------------------------
' vt_net_shutdown -- release networking subsystem, No-op on Linux.
' -----------------------------------------------------------------------------
#Ifdef __FB_WIN32__
    '>>>
    ':topic vt_net_shutdown
    ':short shutdown the networking subsystem (opt-in)
    ':group Networking
    'Shutdown the networking subsystem. 
    'Opt-in: define VT_USE_NET before the include.
    ':syntax
    Sub vt_net_shutdown()
            ':see
            'vt_net_open
            'vt_net_connect
        '<<<
        WSACleanup()
    End Sub
#Else
    Sub vt_net_shutdown()
    End Sub
#Endif

'>>>
':topic vt_net_resolve
':short Hostname lookup and IP string formatting
':group Networking
'Convert between host names and packed IP values.
'vt_net_resolve accepts dotted-decimal strings
'("192.168.0.1") and DNS host names ("example.com")
'and returns the IP as a packed Long in network
'byte order -- the format expected by all other
'vt_net_* functions. vt_net_ip_str converts a
'packed value back to a dotted-decimal string.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_resolve(hostname As ZString Ptr) _
                        As Long

        ':params
        'hostname  Dotted-decimal IP or DNS host name.
        'ip        Packed IP in network byte order, as
        '          returned by vt_net_resolve.
        ':notes
        'Return (vt_net_resolve): packed IP on success,
        '0 on failure (unknown host or bad address).
        'Return (vt_net_ip_str): dotted-decimal string
        'e.g. "93.184.216.34", or "" on failure.
        ':example
        'Dim ip As Long = vt_net_resolve("example.com")
        'If ip = 0 Then
        '    vt_print("Could not resolve host." & VT_LF)
        'Else
        '    vt_print("IP: " & vt_net_ip_str(ip) & VT_LF)
        'End If
        ':see
        'vt_net_connect
        'vt_net_bind
    '<<<
    Dim ia      As in_addr
    Dim entry   As hostent Ptr
    Dim uip     As Ulong
    Dim n       As Long
    Dim pTemp   As Ulong Ptr

    ia.S_addr = inet_addr(hostname)
    If ia.S_addr = INADDR_NONE Then
        entry = gethostbyname(hostname)
        If entry = 0 Then Return 0
        For n = 0 To 99
            pTemp = Cptr(Ulong Ptr, (entry->h_addr_list)[n])
            If pTemp = 0 Then Exit For
            uip = *pTemp
            Exit For
        Next n
        Return uip
    End If
    Return ia.S_addr
End Function

' -----------------------------------------------------------------------------
' vt_net_ip_str -- packed IP Long -> dotted-decimal string "x.x.x.x"
' Returns empty string on failure.
' -----------------------------------------------------------------------------
Function vt_net_ip_str(ip As Long) As String
    Dim ia  As in_addr
    Dim pz  As ZString Ptr
    ia.S_addr = ip
    pz = inet_ntoa(ia)
    If pz Then Return *pz
    Return ""
End Function

'>>>
':topic vt_net_open
':short Create and destroy a socket
':group Networking
'Create and destroy a socket. Pass udp = 1 for
'a UDP datagram socket; the default creates a TCP
'stream socket. After use, always pass the handle
'to vt_net_close to release OS resources.
'SOCKET is a Long on Linux and an opaque platform
'type on Windows. Always treat it as opaque and
'only compare against INVALID_SOCKET.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_open(udp As Byte = 0) As SOCKET_T

        ':params
        'udp   0 = TCP stream socket (default).
        '      1 = UDP datagram socket.
        'sock  Socket handle to close and release.
        ':notes
        'Return (vt_net_open): valid SOCKET on success.
        'INVALID_SOCKET if the OS could not allocate.
        ':example
        'Dim sock As SOCKET = vt_net_open()
        'If sock = INVALID_SOCKET Then
        '    vt_print("Cannot create socket." & VT_LF)
        '    vt_shutdown()
        'End If
        '' ... use sock ...
        'vt_net_close(sock)
        ':see
        'vt_net_connect
        'vt_net_bind
        'vt_net_send
        'vt_net_send_udp
    '<<<
    Dim proto   As Long = Iif(udp, IPPROTO_UDP, IPPROTO_TCP)
    Dim stype   As Long = Iif(udp, SOCK_DGRAM,  SOCK_STREAM)
    #Ifdef __FB_WIN32__
        Return WSASocket(AF_INET, stype, proto, Null, Null, Null)
    #Else
        Return Socket_(AF_INET, stype, proto)
    #Endif
End Function

' -----------------------------------------------------------------------------
' vt_net_close -- close a socket and release its handle
' -----------------------------------------------------------------------------
Sub vt_net_close(sock As SOCKET_T)
    #Ifdef __FB_WIN32__
        closesocket(sock)
    #Else
        close_(sock)
    #Endif
End Sub

'>>>
':topic vt_net_nonblocking
':short Toggle non-blocking mode on a socket
':group Networking
'Toggle non-blocking mode on a socket. In non-
'blocking mode, vt_net_connect, vt_net_send, and
'vt_net_recv return immediately even when the
'operation cannot yet complete. Combine with
'vt_net_ready to integrate network I/O into a
'frame-rate game loop without stalling.
'Opt-in: define VT_USE_NET before the include.
':syntax
Sub vt_net_nonblocking(sock As SOCKET_T, state As Byte)
        ':params
        'sock   Target socket handle.
        'state  1 = enable non-blocking. 0 = blocking.
        ':example
        '' Switch to non-blocking before connect:
        'vt_net_nonblocking(sock, 1)
        ':see
        'vt_net_ready
        'vt_net_connect
    '<<<
    Dim nb As Ulong = Iif(state, 1, 0)
    #Ifdef __FB_WIN32__
        ioctlsocket(sock, FIONBIO, @nb)
    #Else
        ioctl(sock, FIONBIO, @nb)
    #Endif
End Sub

'>>>
':topic vt_net_connect
':short Connect a TCP socket to a remote host
':group Networking
'Connect a TCP socket to a remote host. The
'Nagle algorithm is disabled automatically
'(TCP_NODELAY) to minimise send latency. If the
'socket is in non-blocking mode, the call returns
'immediately with 0 while the connection is in
'progress; use vt_net_ready with for_write = 1
'to detect when the connection is established.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_connect(sock As SOCKET_T, _
                        ip   As Long, _
                        port As Long) As Long
        ':params
        'sock  An open TCP socket from vt_net_open(0).
        'ip    Remote IP in network byte order, from
        '      vt_net_resolve.
        'port  Remote port in host byte order (e.g. 80).
        ':notes
        'Return values:
        '  1  Success (blocking) or immediate accept.
        '  0  Failure or non-blocking in progress.
        ':example
        'Dim sock As SOCKET = vt_net_open()
        'Dim ip   As Long   = vt_net_resolve("example.com")
        'If vt_net_connect(sock, ip, 80) = 0 Then
        '    vt_print("Connection failed." & VT_LF)
        '    vt_net_close(sock)
        '    vt_shutdown()
        'End If
        ':see
        'vt_net_open
        'vt_net_resolve
        'vt_net_send
        'vt_net_ready
        'vt_net_nonblocking
    '<<<
    Dim sa      As sockaddr_in
    Dim nodelay As Long = 1
    sa.sin_family      = AF_INET
    sa.sin_port        = htons(port)
    sa.sin_addr.S_addr = ip
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, Cptr(Any Ptr, @nodelay), Sizeof(nodelay))
    Return Iif(connect(sock, Cptr(sockaddr Ptr, @sa), Sizeof(sa)) <> SOCKET_ERROR, 1, 0)
End Function

'>>>
':topic vt_net_bind
':short TCP server bind, listen, and accept
':group Networking
'Server-side TCP setup. Typical sequence:
'vt_net_bind assigns a local port, vt_net_listen
'begins queuing incoming connections, then
'vt_net_accept is called in a loop to obtain a
'new socket for each client. vt_net_bind is also
'used for UDP sockets that need a fixed local port.
'TCP_NODELAY is set automatically on every socket
'returned by vt_net_accept. Manage each accepted
'socket independently and close it with
'vt_net_close when the client disconnects.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_bind(sock    As SOCKET_T, _
                     port    As Long, _
                     ip      As ULong = _
                     INADDR_ANY) As Long

        ':params
        'sock        The server/listening socket.
        'port        Local port in host byte order.
        'ip          Local interface IP in network byte
        '            order. INADDR_ANY = all interfaces.
        'backlog     Max pending connections. Default
        '            SOMAXCONN (OS maximum).
        'remote_ip   If non-null, receives client IP.
        'remote_port If non-null, receives client port.
        ':notes
        'Return (vt_net_bind, vt_net_listen):
        '  1  success    0  failure
        'Return (vt_net_accept): new SOCKET for the
        'accepted connection, or INVALID_SOCKET if no
        'connection is pending or on error.
        ':example
        'Dim srv As SOCKET = vt_net_open()
        'vt_net_bind(srv, 7000)
        'vt_net_listen(srv)
        'vt_print("Waiting..." & VT_LF)
        'vt_present()
        'Dim client As SOCKET
        'Dim cip As Long, cport As Long
        'Do
        '    client = vt_net_accept(srv, @cip, @cport)
        'Loop While client = INVALID_SOCKET
        'vt_print("Client: " & vt_net_ip_str(cip) & _
        '         ":" & cport & VT_LF)
        ':see
        'vt_net_open
        'vt_net_send
        'vt_net_ready
    '<<<
    Dim sa As sockaddr_in
    sa.sin_family      = AF_INET
    sa.sin_port        = htons(port)
    sa.sin_addr.S_addr = ip
    Return Iif(bind(sock, Cptr(sockaddr Ptr, @sa), Sizeof(sa)) <> SOCKET_ERROR, 1, 0)
End Function

' -----------------------------------------------------------------------------
' vt_net_listen -- put a bound TCP socket into listening mode
' backlog: max queued incoming connections (default: SOMAXCONN)
' Returns 1 on success, 0 on failure.
' -----------------------------------------------------------------------------
Function vt_net_listen(sock As SOCKET_T, backlog As Long = SOMAXCONN) As Long
    Return Iif(listen(sock, backlog) <> SOCKET_ERROR, 1, 0)
End Function

' -----------------------------------------------------------------------------
' vt_net_accept -- accept an incoming TCP connection
' Fills remote_ip and remote_port with the client's address if non-null.
' Returns a new socket handle for the connection, or INVALID_SOCKET on failure.
' -----------------------------------------------------------------------------
Function vt_net_accept(sock As SOCKET_T, remote_ip As Long Ptr = 0, remote_port As Long Ptr = 0) As SOCKET_T
    Dim sa      As sockaddr_in
    Dim salen   As Long = Sizeof(sockaddr_in)
    Dim nodelay As Long = 1
    Dim rsock   As SOCKET_T

    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, Cptr(Any Ptr, @nodelay), Sizeof(nodelay))
    rsock = accept(sock, Cptr(sockaddr Ptr, @sa), @salen)
    If rsock <> INVALID_SOCKET Then
        setsockopt(rsock, IPPROTO_TCP, TCP_NODELAY, Cptr(Any Ptr, @nodelay), Sizeof(nodelay))
        If remote_ip   Then *remote_ip   = sa.sin_addr.S_addr
        If remote_port Then *remote_port = htons(sa.sin_port)
    End If
    Return rsock
End Function

'>>>
':topic vt_net_send
':short Send and receive data on a TCP socket
':group Networking
'Send and receive data on a connected TCP socket.
'Both functions map directly to OS send and recv.
'In blocking mode vt_net_recv waits until data
'arrives or the connection closes; call
'vt_net_ready first to avoid stalling a game loop.
'A single vt_net_send call may send fewer bytes
'than requested -- a robust send loop should retry
'until the full byte count has been delivered.
'vt_net_recv may similarly return fewer bytes than
'nbytes even when more data is on the way.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_send(sock   As SOCKET_T, _
                     buf    As ZString Ptr, _
                     nbytes As Long) As Long

        ':params
        'sock    Connected TCP socket.
        'buf     Pointer to the data buffer.
        'nbytes  Bytes to send, or max bytes to receive.
        ':notes
        'Return (vt_net_send): bytes actually sent,
        'or <= 0 on error or disconnection.
        'Return (vt_net_recv): bytes received. 0 means
        'peer closed gracefully; < 0 is an error.
        ':example
        'Dim msg   As String = "Hello, server!"
        'Dim rxbuf As ZString * 257
        'Dim n     As Long
        '
        'n = vt_net_send(sock, StrPtr(msg), Len(msg))
        'If n <= 0 Then
        '    vt_print("Send error." & VT_LF)
        'End If
        '
        'n = vt_net_recv(sock, @rxbuf, 256)
        'If n > 0 Then
        '    rxbuf[n] = 0
        '    vt_print("Recv: " & rxbuf & VT_LF)
        'ElseIf n = 0 Then
        '    vt_print("Server closed." & VT_LF)
        'End If
        ':see
        'vt_net_ready
        'vt_net_connect
        'vt_net_send_udp
    '<<<
    Return send(sock, buf, nbytes, 0)
End Function

' -----------------------------------------------------------------------------
' vt_net_recv -- receive bytes from a connected TCP socket
' Returns bytes received, 0 = connection closed gracefully, < 0 = error.
' -----------------------------------------------------------------------------
Function vt_net_recv(sock As SOCKET_T, buf As ZString Ptr, nbytes As Long) As Long
    Return recv(sock, buf, nbytes, 0)
End Function

'>>>
':topic vt_net_send_udp
':short Send and receive UDP datagrams
':group Networking
'Send and receive UDP datagrams. A UDP socket
'does not need to be connected; each send call
'specifies the destination explicitly. To receive,
'the socket should first be bound to a local port
'with vt_net_bind. UDP datagrams are delivered in
'full or not at all -- there is no partial-read
'scenario. If the receive buffer is smaller than
'the incoming datagram the excess bytes are
'discarded silently. Delivery is not ordered or
'guaranteed.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_send_udp(sock   As SOCKET_T, _
                         ip     As Long, _
                         port   As Long, _
                         buf    As ZString Ptr, _
                         nbytes As Long) As Long

        ':params
        'sock      An open UDP socket from vt_net_open(1).
        'ip        Destination IP in network byte order.
        'port      Destination port in host byte order.
        'src_ip    Receives sender IP (network byte order).
        'src_port  Receives sender port (host byte order).
        'buf       Pointer to the data buffer.
        'nbytes    Bytes to send, or max bytes to receive.
        ':notes
        'Return (vt_net_send_udp): bytes sent, or <= 0
        'on error.
        'Return (vt_net_recv_udp): bytes received, or
        '<= 0 on error.
        ':example
        'Dim udp_sock As SOCKET = vt_net_open(1)
        'Dim srv_ip   As Long   = vt_net_resolve("192.168.1.10")
        'Dim msg      As String = "ping"
        'vt_net_send_udp(udp_sock, srv_ip, 9999, _
        '                StrPtr(msg), Len(msg))
        '
        'Dim rxbuf As ZString * 257
        'Dim sip As Long, sport As Long
        'Dim n As Long = _
        '    vt_net_recv_udp(udp_sock, sip, sport, @rxbuf, 256)
        'If n > 0 Then
        '    vt_print("Reply from " & vt_net_ip_str(sip) & _
        '             ":" & sport & VT_LF)
        'End If
        'vt_net_close(udp_sock)
        ':see
        'vt_net_open
        'vt_net_bind
        'vt_net_send
    '<<<
    Dim sa As sockaddr_in
    sa.sin_family      = AF_INET
    sa.sin_port        = htons(port)
    sa.sin_addr.S_addr = ip
    Return sendto(sock, buf, nbytes, 0, Cptr(sockaddr Ptr, @sa), Sizeof(sa))
End Function

' -----------------------------------------------------------------------------
' vt_net_recv_udp -- receive a UDP datagram
' Fills src_ip and src_port with the sender's address.
' Returns bytes received, or <= 0 on error.
' -----------------------------------------------------------------------------
Function vt_net_recv_udp(sock As SOCKET_T, Byref src_ip As Long, Byref src_port As Long, buf As ZString Ptr, nbytes As Long) As Long
    Dim sa      As sockaddr_in
    Dim salen   As Long = Sizeof(sockaddr_in)
    Dim result  As Long

    result   = recvfrom(sock, buf, nbytes, 0, Cptr(sockaddr Ptr, @sa), @salen)
    src_ip   = sa.sin_addr.S_addr
    src_port = htons(sa.sin_port)
    Return result
End Function

'>>>
':topic vt_net_ready
':short Non-blocking socket readiness poll
':group Networking
'Non-blocking readiness poll on a single socket
'using select(). Use this before vt_net_recv or
'vt_net_accept in a game loop to avoid blocking
'the frame. Pass timeout_ms = 0 for an instant
'check, or timeout_ms = -1 to block until the
'socket is ready.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_ready(sock       As SOCKET_T, _
                      for_write  As Byte = 0, _
                      timeout_ms As Long = 0) _
                      As Long
        ':params
        'sock        Socket to poll.
        'for_write   0 = check if data is available to
        '            read (default). 1 = check if send
        '            buffer has space.
        'timeout_ms  Timeout in ms. 0 = return immediately.
        '            -1 = block until socket is ready.
        ':notes
        'Return values:
        '   1  Socket is ready for the requested operation.
        '   0  Timeout expired with no activity.
        '  -1  Error.
        ':example
        '' Non-blocking receive in a game loop:
        'Dim rxbuf     As ZString * 257
        'Dim connected As Long = 1
        'Dim k         As ULong
        'Dim n         As Long
        'Do
        '    k = vt_inkey()
        '    If vt_net_ready(sock) Then
        '        n = vt_net_recv(sock, @rxbuf, 256)
        '        If n > 0 Then
        '            rxbuf[n] = 0
        '        ElseIf n = 0 Then
        '            connected = 0
        '        End If
        '    End If
        '    vt_sleep 16
        'Loop While connected
        ':see
        'vt_net_send
        'vt_net_bind
        'vt_net_nonblocking
    '<<<
    Dim tv      As timeval
    Dim tvp     As timeval Ptr
    Dim tSock   As fd_set

    If timeout_ms >= 0 Then
        tv.tv_sec  = timeout_ms \ 1000
        tv.tv_usec = (timeout_ms Mod 1000) * 1000
        tvp = @tv
    Else
        tvp = 0  ' block until ready
    End If

    FD_SET_(sock, @tSock)
    If for_write Then
        Return select_(sock + 1, 0, @tSock, 0, tvp)
    Else
        Return select_(sock + 1, @tSock, 0, 0, tvp)
    End If
End Function

'>>>
':topic vt_net_local_addr
':short Query the local IP and port of a socket
':group Networking
'Query the local IP address and port that the OS
'has assigned to a socket. Useful after
'vt_net_connect to discover the ephemeral port
'chosen by the OS, or after vt_net_bind to
'confirm the binding.
'Opt-in: define VT_USE_NET before the include.
':syntax
Function vt_net_local_addr(sock As SOCKET_T, _
                           ByRef local_ip   As Long, _
                           ByRef local_port As Long) _
                           As Long
        ':params
        'sock        A bound or connected socket.
        'local_ip    Receives local IP in network byte order.
        'local_port  Receives local port in host byte order.
        ':notes
        'Return: 1 on success, 0 on failure.
        ':example
        'Dim lip   As Long
        'Dim lport As Long
        'If vt_net_local_addr(sock, lip, lport) Then
        '    vt_print("Local: " & vt_net_ip_str(lip) & _
        '             ":" & lport & VT_LF)
        'End If
        ':see
        'vt_net_bind
        'vt_net_connect
    '<<<
    Dim sa      As sockaddr_in
    Dim salen   As Long = Sizeof(sockaddr_in)
    Dim result  As Long

    result     = getsockname(sock, Cptr(sockaddr Ptr, @sa), @salen)
    local_ip   = sa.sin_addr.S_addr
    local_port = htons(sa.sin_port)
    Return Iif(result = 0, 1, 0)
End Function
