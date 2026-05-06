#include once "vt_tls.bi"

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