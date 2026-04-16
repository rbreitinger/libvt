' ===========================================================
' ex_net_tcp.bas
' Tests: vt_net_open (TCP), vt_net_connect, vt_net_local_addr,
'        vt_net_ready (read + write), vt_net_send, vt_net_recv,
'        vt_net_close
' Connects to example.com:80, sends a minimal HTTP/1.0 GET,
' reads first chunk of the response.
' Requires internet access.
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

Dim k           As ULong
Dim sock        As SOCKET
Dim ip          As Long
Dim lip         As Long
Dim lport       As Long
Dim ret         As Long
Dim rbuf        As ZString * 1024
Dim rbytes      As Long
Dim req         As String
Dim sip         As String
Dim crow        As Long
Dim np          As Long
Dim nf          As Long
Dim has_http    As Long

vt_screen
vt_title "ex_net_tcp"
vt_cls
vt_color 15, 0 : vt_locate 1, 2 : vt_print "vt_net -- TCP test  (example.com:80)"
vt_color 8,  0 : vt_locate 2, 2 : vt_print String(76, Chr(196))

crow = 4
np   = 0
nf   = 0

ret = vt_net_init()
show_res crow, "vt_net_init()", IIf(ret = 0, 1, 0), "ret=" & ret, np, nf : crow += 1

sock = vt_net_open(0)
show_res crow, "vt_net_open(TCP)", IIf(sock <> INVALID_SOCKET, 1, 0), "sock=" & sock, np, nf : crow += 1

ip = vt_net_resolve("example.com")
show_res crow, "vt_net_resolve(""example.com"")", IIf(ip <> 0, 1, 0), vt_net_ip_str(ip), np, nf : crow += 1

ret = vt_net_connect(sock, ip, 80)
show_res crow, "vt_net_connect(:80)", IIf(ret = 1, 1, 0), "ret=" & ret, np, nf : crow += 1

' vt_net_local_addr requires the ByRef fix in vt_net.bas
lip   = 0
lport = 0
ret = vt_net_local_addr(sock, lip, lport)
sip = vt_net_ip_str(lip)
show_res crow, "vt_net_local_addr()", IIf(ret = 1, 1, 0), sip & ":" & lport, np, nf : crow += 1

ret = vt_net_ready(sock, 1, 200)
show_res crow, "vt_net_ready(write, 200ms)", IIf(ret = 1, 1, 0), "ret=" & ret, np, nf : crow += 1

req = "GET / HTTP/1.0" & Chr(13) & Chr(10) & _
      "Host: example.com" & Chr(13) & Chr(10) & _
      Chr(13) & Chr(10)
ret = vt_net_send(sock, StrPtr(req), CLng(Len(req)))
show_res crow, "vt_net_send(HTTP GET)", IIf(ret > 0, 1, 0), "bytes=" & ret, np, nf : crow += 1

ret = vt_net_ready(sock, 0, 4000)
show_res crow, "vt_net_ready(read, 4000ms)", IIf(ret = 1, 1, 0), "ret=" & ret, np, nf : crow += 1

rbytes = vt_net_recv(sock, @rbuf, 1023)
has_http = IIf(rbytes >= 4 AndAlso rbuf[0] = Asc("H") AndAlso rbuf[1] = Asc("T") AndAlso rbuf[2] = Asc("T") AndAlso rbuf[3] = Asc("P"), 1, 0)
show_res crow, "vt_net_recv(got HTTP/ response)", IIf(rbytes > 0, 1, 0), "bytes=" & rbytes & "  starts-HTTP=" & has_http, np, nf : crow += 1

vt_net_close(sock)
vt_color 8, 0 : vt_locate crow, 2 : vt_print "vt_net_close()  done" : crow += 1

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
