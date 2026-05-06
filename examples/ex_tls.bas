#define VT_USE_NET
#define VT_USE_TLS
#include once "../vt/vt.bi"

Const TEST_HOST = "gemini.circumlunar.space"
Const TEST_PORT = 1965
Const TEST_URL  = "gemini://gemini.circumlunar.space/" & Chr(13) & Chr(10)

Dim sock    As SOCKET
Dim conn    As Any Ptr
Dim ip      As Long
Dim ret     As Long
Dim recv_ch As ZString * 4096
Dim fprint  As String
Dim chunk   As Long

Print "Initializing network ..."
If vt_net_init() <> 0 Then
    Print "ERROR: vt_net_init failed"
    End 1
End If

Print "Resolving " & TEST_HOST & " ..."
ip = vt_net_resolve(TEST_HOST)
If ip = 0 Then
    Print "ERROR: resolve failed"
    End 1
End If
Print "  -> " & vt_net_ip_str(ip)

Print "Opening TCP socket ..."
sock = vt_net_open()
If sock = INVALID_SOCKET Then
    Print "ERROR: socket open failed"
    End 1
End If

Print "Connecting TCP port " & TEST_PORT & " ..."
ret = vt_net_connect(sock, ip, TEST_PORT)
If ret <> 1 Then
    Print "ERROR: TCP connect failed"
    vt_net_close(sock)
    End 1
End If
Print "  -> TCP connected"

Print "TLS handshake ..."
ret = vt_tls_connect(sock, TEST_HOST, conn)
If ret <> 0 Then
    Print "ERROR: TLS handshake failed"
    vt_net_close(sock)
    End 1
End If
Print "  -> handshake ok"

fprint = vt_tls_fingerprint(conn)
Print "  -> cert SHA-256: " & fprint

Print "Sending Gemini request ..."
Dim req As String = TEST_URL
ret = vt_tls_send(conn, StrPtr(req), Len(req))
If ret < 0 Then
    Print "ERROR: send failed"
    vt_tls_disconnect(conn)
    vt_net_close(sock)
    End 1
End If
Print "  -> sent " & ret & " bytes"

Print "Reading response ..."
Print "---"
chunk = vt_tls_recv(conn, @recv_ch, SizeOf(recv_ch) - 1)
If chunk > 0 Then
    recv_ch[chunk] = 0
    Print recv_ch
End If
Print "---"

vt_tls_disconnect(conn)
vt_net_close(sock)
vt_net_shutdown()
Print "Done."

sleep
vt_shutdown()