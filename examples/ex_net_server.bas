' ===========================================================
' ex_net_server.bas
' Tests: vt_net_bind, vt_net_listen, vt_net_accept,
'        vt_net_nonblocking, vt_net_send, vt_net_recv,
'        vt_net_close
' Starts a TCP echo server on port 7777.
' Connect with: telnet localhost 7777  or  nc localhost 7777
' Press ESC to exit.
' ===========================================================
#define VT_USE_NET
#include once "../vt/vt.bi"

Const SRV_PORT  = 7777
Const COL_LBL   = 2
Const COL_VAL   = 20

Sub status_row(row As Long, lbl As String, value As String, col As Long)
    Dim padlen  As Long
    vt_locate row, COL_LBL
    vt_color 8, 0  : vt_print lbl
    vt_locate row, COL_VAL
    padlen = 78 - COL_VAL - Len(value)
    If padlen < 0 Then padlen = 0
    vt_color col, 0 : vt_print value & String(padlen, " ")
End Sub

Dim k           As ULong
Dim lsock       As SOCKET
Dim csock       As SOCKET
Dim client_ip   As Long
Dim client_prt  As Long
Dim rbuf        As ZString * 512
Dim rbytes      As Long
Dim ret         As Long
Dim total_echo  As Long
Dim state       As Long   ' 0=init 1=listening 2=connected 3=done

vt_screen
vt_title "ex_net_server"
vt_cls
vt_color 15, 0 : vt_locate 1, COL_LBL : vt_print "vt_net -- TCP echo server  port " & SRV_PORT
vt_color 8,  0 : vt_locate 2, COL_LBL : vt_print String(76, Chr(196))

vt_color 8, 0
vt_locate  4, COL_LBL : vt_print "bind:"
vt_locate  5, COL_LBL : vt_print "listen:"
vt_locate  6, COL_LBL : vt_print "state:"
vt_locate  7, COL_LBL : vt_print "client:"
vt_locate  8, COL_LBL : vt_print "echoed:"
vt_locate 22, COL_LBL : vt_print "ESC = quit"

total_echo = 0
state      = 0
csock      = INVALID_SOCKET

' --- init + bind + listen --------------------------------
ret = vt_net_init()
If ret <> 0 Then
    status_row 4, "init:", "FAIL ret=" & ret, 12
    vt_sleep 2000
    vt_shutdown()
    End
End If

lsock = vt_net_open(0)
If lsock = INVALID_SOCKET Then
    status_row 4, "bind:", "FAIL (open)", 12
    vt_sleep 2000
    vt_net_shutdown()
    vt_shutdown()
    End
End If

ret = vt_net_bind(lsock, SRV_PORT)
status_row 4, "bind:", IIf(ret = 1, "OK  port " & SRV_PORT, "FAIL ret=" & ret), IIf(ret = 1, 10, 12)

ret = vt_net_listen(lsock)
status_row 5, "listen:", IIf(ret = 1, "OK", "FAIL ret=" & ret), IIf(ret = 1, 10, 12)

If ret = 0 Then
    vt_sleep 2000
    vt_net_close lsock
    vt_net_shutdown()
    vt_shutdown()
    End
End If

' non-blocking accept so the UI stays responsive
vt_net_nonblocking lsock, 1
state = 1

' --- main loop -------------------------------------------
Do
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC  Then Exit Do

    Select Case state
        Case 1   ' waiting for connection
            status_row 6, "state:", "waiting for connection...", 14
            csock = vt_net_accept(lsock, @client_ip, @client_prt)
            If csock <> INVALID_SOCKET Then
                status_row 7, "client:", vt_net_ip_str(client_ip) & ":" & client_prt, 11
                state = 2
            End If

        Case 2   ' connected -- echo loop
            status_row 6, "state:", "connected -- echoing", 10
            ret = vt_net_ready(csock, 0, 0)
            If ret = 1 Then
                rbytes = vt_net_recv(csock, @rbuf, 511)
                If rbytes > 0 Then
                    vt_net_send csock, @rbuf, rbytes
                    total_echo += rbytes
                    status_row 8, "echoed:", total_echo & " bytes", 7
                ElseIf rbytes <= 0 Then
                    ' client disconnected
                    vt_net_close csock
                    csock = INVALID_SOCKET
                    status_row 6, "state:", "client disconnected", 8
                    status_row 7, "client:", "-", 8
                    state = 1
                End If
            End If
    End Select

    vt_sleep 20
Loop

' --- cleanup ---------------------------------------------
If csock <> INVALID_SOCKET Then vt_net_close csock
vt_net_close lsock
vt_net_shutdown()

status_row 6, "state:", "shut down", 8
vt_color 8, 0 : vt_locate 22, COL_LBL : vt_print "done -- echoed " & total_echo & " bytes total"
vt_sleep() 
vt_shutdown()