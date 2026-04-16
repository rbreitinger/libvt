' ===========================================================
' ex_net_resolve.bas
' Tests: vt_net_init, vt_net_resolve, vt_net_ip_str,
'        vt_net_shutdown
' Requires DNS/network access for the hostname test.
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

Dim k       As ULong
Dim ip1     As Long
Dim ip2     As Long
Dim sip     As String
Dim ret     As Long
Dim crow    As Long
Dim np      As Long
Dim nf      As Long

vt_screen
vt_title "ex_net_resolve"
vt_cls
vt_color 15, 0 : vt_locate 1, 2 : vt_print "vt_net -- resolve / ip_str test"
vt_color 8,  0 : vt_locate 2, 2 : vt_print String(76, Chr(196))

crow = 4
np   = 0
nf   = 0

ret = vt_net_init()
show_res crow, "vt_net_init()", IIf(ret = 0, 1, 0), "ret=" & ret, np, nf : crow += 1

ip1 = vt_net_resolve("example.com")
show_res crow, "vt_net_resolve(""example.com"")", IIf(ip1 <> 0, 1, 0), "raw=" & Hex(ip1), np, nf : crow += 1

sip = vt_net_ip_str(ip1)
show_res crow, "vt_net_ip_str(resolved ip)", IIf(sip <> "", 1, 0), """" & sip & """", np, nf : crow += 1

ip2 = vt_net_resolve("93.184.216.34")
show_res crow, "vt_net_resolve(""93.184.216.34"")", IIf(ip2 <> 0, 1, 0), "raw=" & Hex(ip2), np, nf : crow += 1

sip = vt_net_ip_str(ip2)
show_res crow, "vt_net_ip_str roundtrip", IIf(sip = "93.184.216.34", 1, 0), """" & sip & """", np, nf : crow += 1

ip1 = vt_net_resolve("this.should.never.resolve.invalid")
show_res crow, "vt_net_resolve(bad host) -> 0", IIf(ip1 = 0, 1, 0), "raw=" & ip1, np, nf : crow += 2

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
