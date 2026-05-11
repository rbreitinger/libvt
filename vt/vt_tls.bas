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

' -- Public API ---------------------------------------------------------------
' vt_tls_connect : TLS handshake on an already-connected TCP socket.
'                  sock     = socket from vt_net_connect
'                  hostname = server hostname string (used for SNI)
'                  conn     = receives opaque connection handle
'                  returns  0 ok, -1 handshake failed
Declare Function vt_tls_connect    (sock As SOCKET, hostname As String, ByRef conn As Any Ptr) As Long

' vt_tls_send    : returns bytes sent, -1 on error
Declare Function vt_tls_send       (conn As Any Ptr, buf As ZString Ptr, nbytes As Long) As Long

' vt_tls_recv    : returns bytes received, 0 no data yet, -1 closed, -2 error
Declare Function vt_tls_recv       (conn As Any Ptr, buf As ZString Ptr, nbytes As Long) As Long

' vt_tls_fingerprint : SHA-256 of peer cert as 64 hex chars, "" on failure
Declare Function vt_tls_fingerprint(conn As Any Ptr) As String

' vt_tls_disconnect  : graceful shutdown + free, sets conn = 0
Declare Sub      vt_tls_disconnect (ByRef conn As Any Ptr)

Function vt_tls_connect(sock As SOCKET, hostname As String, ByRef conn As Any Ptr) As Long
    conn = vt_tls_open(CLng(sock), hostname)
    If conn = 0 Then Return -1
    Return 0
End Function

Function vt_tls_send(conn As Any Ptr, buf As ZString Ptr, nbytes As Long) As Long
    Return vt_tls_write(conn, buf, nbytes)
End Function

Function vt_tls_recv(conn As Any Ptr, buf As ZString Ptr, nbytes As Long) As Long
    Return vt_tls_read(conn, buf, nbytes)
End Function

Function vt_tls_fingerprint(conn As Any Ptr) As String
    If conn = 0 Then Return ""
    Dim hex_buf As ZString * 65
    If vt_tls_peer_fingerprint(conn, @hex_buf) <> 0 Then Return ""
    Return hex_buf
End Function

Sub vt_tls_disconnect(ByRef conn As Any Ptr)
    If conn = 0 Then Exit Sub
    vt_tls_close(conn)
    conn = 0
End Sub