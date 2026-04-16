' ===========================================================
' ex_net_udp.bas
' Tests: vt_net_open (UDP), vt_net_bind, vt_net_nonblocking,
'        vt_net_send_udp, vt_net_ready, vt_net_recv_udp,
'        vt_net_close
' Loopback only -- no internet access needed.
' Two sockets on 127.0.0.1: sock_a on 19001, sock_b on 19002.
' sock_b sends a datagram to sock_a, sock_a reads it back.
' ===========================================================
#define VT_USE_NET
#include once "../vt/vt.bi"

Sub show_res(row As Long, tag As String, ok As Long, detail As String, ByRef np As Long, ByRef nf As Long)
    Dim padded As String
    padded = tag
    While Len(padded) < 44 : padded += " " : Wend
    vt_locate row, 2
    vt_color 7, 0 : vt_print padded
    If ok Then
        vt_color 10, 0 : vt_print "OK  "
        np += 1
    Else
        vt_color 12, 0 : vt_print "FAIL"
        nf += 1
    End If
    vt_color 7, 0
    If detail <> "" Then vt_print "  " & detail
End Sub

Const TEST_MSG   = "hello vt_net udp"
Const PORT_A     = 19001
Const PORT_B     = 19002

Dim k           As ULong
Dim sock_a      As SOCKET
Dim sock_b      As SOCKET
Dim loopback    As Long
Dim src_ip      As Long
Dim src_prt     As Long
Dim rbuf        As ZString * 256
Dim rbytes      As Long
Dim ret         As Long
Dim smsg        As String
Dim crow        As Long
Dim np          As Long
Dim nf          As Long

vt_screen
vt_title "ex_net_udp"
vt_cls
vt_color 15, 0 : vt_locate 1, 2 : vt_print "vt_net -- UDP loopback test"
vt_color 8,  0 : vt_locate 2, 2 : vt_print String(76, Chr(196))

crow = 4
np   = 0
nf   = 0

ret = vt_net_init()
show_res crow, "vt_net_init()", IIf(ret = 0, 1, 0), "ret=" & ret, np, nf : crow += 1

sock_a = vt_net_open(1)
show_res crow, "vt_net_open(UDP) sock_a", IIf(sock_a <> INVALID_SOCKET, 1, 0), "sock=" & sock_a, np, nf : crow += 1

sock_b = vt_net_open(1)
show_res crow, "vt_net_open(UDP) sock_b", IIf(sock_b <> INVALID_SOCKET, 1, 0), "sock=" & sock_b, np, nf : crow += 1

ret = vt_net_bind(sock_a, PORT_A)
show_res crow, "vt_net_bind(sock_a, " & PORT_A & ")", IIf(ret = 1, 1, 0), "ret=" & ret, np, nf : crow += 1

ret = vt_net_bind(sock_b, PORT_B)
show_res crow, "vt_net_bind(sock_b, " & PORT_B & ")", IIf(ret = 1, 1, 0), "ret=" & ret, np, nf : crow += 1

loopback = vt_net_resolve("127.0.0.1")
show_res crow, "vt_net_resolve(""127.0.0.1"")", IIf(loopback <> 0, 1, 0), Hex(loopback), np, nf : crow += 1

' set sock_a non-blocking, recv with no data yet should return < 0 immediately
vt_net_nonblocking sock_a, 1
rbytes = vt_net_recv_udp(sock_a, src_ip, src_prt, @rbuf, 255)
show_res crow, "vt_net_nonblocking + recv (no data)", IIf(rbytes < 0, 1, 0), "ret=" & rbytes & " (EAGAIN expected)", np, nf : crow += 1

' restore blocking before the real recv
vt_net_nonblocking sock_a, 0

' send datagram from sock_b to sock_a
smsg = TEST_MSG
ret = vt_net_send_udp(sock_b, loopback, PORT_A, StrPtr(smsg), CLng(Len(smsg)))
show_res crow, "vt_net_send_udp(sock_b -> " & PORT_A & ")", IIf(ret = Len(smsg), 1, 0), "bytes=" & ret, np, nf : crow += 1

ret = vt_net_ready(sock_a, 0, 2000)
show_res crow, "vt_net_ready(sock_a read, 2000ms)", IIf(ret = 1, 1, 0), "ret=" & ret, np, nf : crow += 1

src_ip  = 0
src_prt = 0
rbytes  = vt_net_recv_udp(sock_a, src_ip, src_prt, @rbuf, 255)
show_res crow, "vt_net_recv_udp(sock_a)", IIf(rbytes > 0, 1, 0), "bytes=" & rbytes & "  from=" & vt_net_ip_str(src_ip) & ":" & src_prt, np, nf : crow += 1

' verify src port matches PORT_B and content matches
show_res crow, "recv src_port = " & PORT_B, IIf(src_prt = PORT_B, 1, 0), "got=" & src_prt, np, nf : crow += 1

Dim gotmsg As String
gotmsg = Left(rbuf, rbytes)
show_res crow, "recv content matches TEST_MSG", IIf(gotmsg = TEST_MSG, 1, 0), """" & gotmsg & """", np, nf : crow += 2

vt_net_close sock_a
vt_net_close sock_b
vt_color 8, 0 : vt_locate crow, 2 : vt_print "vt_net_close(x2)  done" : crow += 1

vt_net_shutdown()
vt_color 8, 0 : vt_locate crow, 2 : vt_print "vt_net_shutdown()  done" : crow += 2

If nf = 0 Then
    vt_color 10, 0
Else
    vt_color 12, 0
End If
vt_locate crow, 2 : vt_print np & " passed, " & nf & " failed" : crow += 2

vt_color 7, 0 : vt_locate crow, 2 : vt_print "Press any key..."
Do
    k = vt_inkey()
    vt_sleep 10
Loop Until k <> 0
vt_shutdown()
