' based on mbedtls-2.28.10 -- https://github.com/Mbed-TLS/mbedtls

#pragma once

#ifdef __FB_WIN32__
    #define _inclibrelpath( _LibPath ) #inclib __FB_EVAL__("fb -L"__PATH__ _LibPath)
    _inclibrelpath(".")
    #ifdef __FB_64BIT__
        #inclib "mbedtls_win64"
    #else
        #inclib "mbedtls_win32"
    #endif
#else
    #inclib __FB_EVAL__("fb -L"__PATH__)
    #ifdef __FB_64BIT__
        #inclib "mbedtls_linux64"
    #else
        #inclib "mbedtls_linux32"
    #endif
#endif

' -- C glue layer (internal, do not call directly) ----------------------------
Extern "C"
    Declare Function vt_tls_open            (sock As Long, hostname As ZString Ptr) As Any Ptr
    Declare Function vt_tls_write           (cn As Any Ptr, buf As ZString Ptr, nbytes As Long) As Long
    Declare Function vt_tls_read            (cn As Any Ptr, buf As ZString Ptr, nbytes As Long) As Long
    Declare Function vt_tls_peer_fingerprint(cn As Any Ptr, out_hex As ZString Ptr) As Long
    Declare Sub      vt_tls_close           (cn As Any Ptr)
End Extern

'>>>
':topic vt_tls_connect
':short TLS handshake on a connected TCP socket (opt-in)
':group Networking-TLS
'Perform a TLS handshake on an already-connected
'TCP socket obtained from vt_net_connect.
'hostname is used for SNI and must match the
'server's certificate CN or SAN. On success conn
'receives an opaque handle used by all other
'vt_tls_* functions; on failure it is set to 0.
'Requires VT_USE_NET. Opt-in: define VT_USE_TLS
'before the include.
':syntax
Function vt_tls_connect(sock       As SOCKET_T, _
                        hostname   As String, _
                        ByRef conn As Any Ptr) _
                        As Long
        ':params
        'sock      An already-connected TCP socket (from vt_net_connect).
        'hostname  Server hostname for SNI -- must match the certificate.
        'conn      Receives the opaque TLS handle (0 on failure).
        ':notes
        'Return:
        '   0  success
        '  -1  TLS handshake failed
        ':example
        'Dim sock As SOCKET = vt_net_open()
        'Dim ip   As Long   = vt_net_resolve("example.com")
        'vt_net_connect(sock, ip, 443)
        '
        'Dim conn As Any Ptr
        'If vt_tls_connect(sock, "example.com", conn) <> 0 Then
        '    vt_print("TLS handshake failed." & VT_LF)
        '    vt_net_close(sock)
        'End If
        ':see
        'vt_net_connect
        'vt_tls_send
        'vt_tls_disconnect
    '<<<
    conn = vt_tls_open(CLng(sock), hostname)
    If conn = 0 Then Return -1
    Return 0
End Function

'>>>
':topic vt_tls_send
':short Send data over a TLS connection (opt-in)
':group Networking-TLS
'Send nbytes bytes from buf over an established
'TLS connection. Like the underlying TCP send,
'this may send fewer bytes than requested -- loop
'until all bytes are consumed when full delivery
'is required.
'Requires VT_USE_NET. Opt-in: define VT_USE_TLS
'before the include.
':syntax
Function vt_tls_send(conn   As Any Ptr, _
                     buf    As ZString Ptr, _
                     nbytes As Long) As Long
        ':params
        'conn    Opaque TLS handle from vt_tls_connect.
        'buf     Data to send.
        'nbytes  Number of bytes to send from buf.
        ':notes
        'Return:
        '  >= 1  bytes sent
        '    -1  error
        ':example
        'Dim req  As String = "GET / HTTP/1.0" & Chr(13,10) & _
        '                     "Host: example.com" & Chr(13,10,13,10)
        'Dim sent As Long = 0
        'Do While sent < Len(req)
        '    Dim n As Long = vt_tls_send(conn, StrPtr(req) + sent, _
        '                                Len(req) - sent)
        '    If n < 1 Then Exit Do
        '    sent += n
        'Loop
        ':see
        'vt_tls_connect
        'vt_tls_recv
    '<<<
    Return vt_tls_write(conn, buf, nbytes)
End Function

'>>>
':topic vt_tls_recv
':short Receive data over a TLS connection (opt-in)
':group Networking-TLS
'Receive up to nbytes bytes into buf from an
'established TLS connection. When the underlying
'socket is set to non-blocking mode via
'vt_net_nonblocking, returns 0 immediately if
'no data is available yet.
'Requires VT_USE_NET. Opt-in: define VT_USE_TLS
'before the include.
':syntax
Function vt_tls_recv(conn   As Any Ptr, _
                     buf    As ZString Ptr, _
                     nbytes As Long) As Long
        ':params
        'conn    Opaque TLS handle from vt_tls_connect.
        'buf     Buffer that receives the incoming data.
        'nbytes  Maximum bytes to read into buf.
        ':notes
        'Return:
        '  >= 1  bytes received
        '     0  no data yet (non-blocking socket)
        '    -1  peer closed cleanly (close_notify)
        '    -2  connection error
        ':example
        'Dim rxbuf As ZString * 4097
        'Dim n     As Long
        'Do
        '    n = vt_tls_recv(conn, @rxbuf, 4096)
        '    If n > 0 Then
        '        rxbuf[n] = 0
        '        vt_print(rxbuf & VT_LF)
        '    End If
        'Loop While n > 0
        ':see
        'vt_tls_send
        'vt_net_nonblocking
    '<<<
    Return vt_tls_read(conn, buf, nbytes)
End Function

'>>>
':topic vt_tls_fingerprint
':short SHA-256 certificate fingerprint for TOFU (opt-in)
':group Networking-TLS
'Returns the SHA-256 fingerprint of the peer's
'certificate DER encoding as a 64-character
'lowercase hex string. Use for Trust On First
'Use (TOFU): store on first contact, compare on
'subsequent connections to detect cert changes.
'Requires VT_USE_NET. Opt-in: define VT_USE_TLS
'before the include.
':syntax
Function vt_tls_fingerprint(conn As Any Ptr) _
                             As String
        ':params
        'conn  Opaque TLS handle from vt_tls_connect.
        ':notes
        'Return: 64-char lowercase hex string (SHA-256).
        '        "" if conn = 0 or no peer cert available.
        ':example
        'Dim fp As String = vt_tls_fingerprint(conn)
        'vt_print("Certificate SHA-256: " & fp & VT_LF)
        ':see
        'vt_tls_connect
    '<<<
    If conn = 0 Then Return ""
    Dim hex_buf As ZString * 65
    If vt_tls_peer_fingerprint(conn, @hex_buf) <> 0 Then Return ""
    Return hex_buf
End Function

'>>>
':topic vt_tls_disconnect
':short Graceful TLS shutdown and resource release (opt-in)
':group Networking-TLS
'Send a TLS close_notify alert, free all internal
'TLS resources, and set conn to 0. Always call
'this before vt_net_close on the same socket to
'ensure a clean protocol shutdown.
'Requires VT_USE_NET. Opt-in: define VT_USE_TLS
'before the include.
':syntax
Sub vt_tls_disconnect(ByRef conn As Any Ptr)
        ':params
        'conn  Opaque TLS handle. Set to 0 on return.
        ':example
        'vt_tls_disconnect(conn)
        'vt_net_close(sock)
        'vt_net_shutdown()
        ':see
        'vt_tls_connect
        'vt_net_open
    '<<<
    If conn = 0 Then Exit Sub
    vt_tls_close(conn)
    conn = 0
End Sub