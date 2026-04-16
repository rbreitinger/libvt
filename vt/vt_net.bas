' =============================================================================
' vt_net.bas -- opt-in TCP/UDP networking extension for libvt
' pure OS sockets (Winsock2 on Windows, POSIX on Linux).
' =============================================================================
#Ifdef __FB_WIN32__
    #Undef Integer
    #Define Integer Long
    #Include Once "win/winsock2.bi"
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
    Function vt_net_init() As Long
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
    Sub vt_net_shutdown()
        WSACleanup()
    End Sub
#Else
    Sub vt_net_shutdown()
    End Sub
#Endif

' -----------------------------------------------------------------------------
' vt_net_resolve -- hostname or dotted-decimal string -> packed IP as Long
' Returns 0 on failure.
' -----------------------------------------------------------------------------
Function vt_net_resolve(hostname As ZString Ptr) As Long
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

' -----------------------------------------------------------------------------
' vt_net_open -- create a TCP (default) or UDP socket
' udp: 0 = TCP (default), 1 = UDP
' Returns socket handle, or INVALID_SOCKET on failure.
' -----------------------------------------------------------------------------
Function vt_net_open(udp As Byte = 0) As SOCKET_T
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

' -----------------------------------------------------------------------------
' vt_net_nonblocking -- toggle non-blocking mode on a socket
' state: 1 = non-blocking, 0 = blocking
' -----------------------------------------------------------------------------
Sub vt_net_nonblocking(sock As SOCKET_T, state As Byte)
    Dim nb As Ulong = Iif(state, 1, 0)
    #Ifdef __FB_WIN32__
        ioctlsocket(sock, FIONBIO, @nb)
    #Else
        ioctl(sock, FIONBIO, @nb)
    #Endif
End Sub

' -----------------------------------------------------------------------------
' vt_net_connect -- connect a TCP socket to ip:port
' ip: packed Long from vt_net_resolve.
' Disables Nagle algorithm (TCP_NODELAY) for low-latency sends.
' Returns 1 on success, 0 on failure.
' -----------------------------------------------------------------------------
Function vt_net_connect(sock As SOCKET_T, ip As Long, port As Long) As Long
    Dim sa      As sockaddr_in
    Dim nodelay As Long = 1
    sa.sin_family      = AF_INET
    sa.sin_port        = htons(port)
    sa.sin_addr.S_addr = ip
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, Cptr(Any Ptr, @nodelay), Sizeof(nodelay))
    Return Iif(connect(sock, Cptr(sockaddr Ptr, @sa), Sizeof(sa)) <> SOCKET_ERROR, 1, 0)
End Function

' -----------------------------------------------------------------------------
' vt_net_bind -- bind socket to a local port (TCP server or UDP)
' ip: local interface to bind to, defaults to INADDR_ANY (all interfaces).
' Returns 1 on success, 0 on failure.
' -----------------------------------------------------------------------------
Function vt_net_bind(sock As SOCKET_T, port As Long, ip As Ulong = INADDR_ANY) As Long
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

' -----------------------------------------------------------------------------
' vt_net_send -- send bytes over a connected TCP socket
' Returns bytes sent, or <= 0 on error / disconnection.
' -----------------------------------------------------------------------------
Function vt_net_send(sock As SOCKET_T, buf As ZString Ptr, nbytes As Long) As Long
    Return send(sock, buf, nbytes, 0)
End Function

' -----------------------------------------------------------------------------
' vt_net_recv -- receive bytes from a connected TCP socket
' Returns bytes received, 0 = connection closed gracefully, < 0 = error.
' -----------------------------------------------------------------------------
Function vt_net_recv(sock As SOCKET_T, buf As ZString Ptr, nbytes As Long) As Long
    Return recv(sock, buf, nbytes, 0)
End Function

' -----------------------------------------------------------------------------
' vt_net_send_udp -- send a UDP datagram to ip:port
' Returns bytes sent, or <= 0 on error.
' -----------------------------------------------------------------------------
Function vt_net_send_udp(sock As SOCKET_T, ip As Long, port As Long, buf As ZString Ptr, nbytes As Long) As Long
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

' -----------------------------------------------------------------------------
' vt_net_ready -- check if a socket is ready to read or write
' for_write:  0 = check readable (data arrived), 1 = check writable (send buffer free)
' timeout_ms: 0 = return immediately, -1 = block until ready
' Returns 1 if ready, 0 if timed out, -1 on error.
' -----------------------------------------------------------------------------
Function vt_net_ready(sock As SOCKET_T, for_write As Byte = 0, timeout_ms As Long = 0) As Long
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

' -----------------------------------------------------------------------------
' vt_net_local_addr -- query the local IP and port of a socket
' Useful after connect() to discover the ephemeral port assigned by the OS.
' Returns 1 on success, 0 on failure.
' -----------------------------------------------------------------------------
Function vt_net_local_addr(sock As SOCKET_T, Byref local_ip As Long, Byref local_port As Long) As Long
    Dim sa      As sockaddr_in
    Dim salen   As Long = Sizeof(sockaddr_in)
    Dim result  As Long

    result     = getsockname(sock, Cptr(sockaddr Ptr, @sa), @salen)
    local_ip   = sa.sin_addr.S_addr
    local_port = htons(sa.sin_port)
    Return Iif(result = 0, 1, 0)
End Function
