' =============================================================================
' vt_sound.bas : opt-in Sound Extension
' Generates waveform samples and queues them via _VT_DRV_QueueAudio.
' =============================================================================

'>>>
':topic c_soundconsts
':short Sound constants (opt-in: VT_USE_SOUND)
':group Constants
'Available when #define VT_USE_SOUND is placed
'before #include once "vt/vt.bi".
'
':params
' Waveforms (wave parameter of vt_sound):
Const VT_WAVE_SQUARE      = 0       ' PC speaker / chiptune square wave (default)
Const VT_WAVE_TRIANGLE    = 1       ' NES triangle channel -- softer, bass feel
Const VT_WAVE_SINE        = 2       ' pure sine tone
Const VT_WAVE_NOISE       = 3       ' 15-bit LFSR noise -- NES percussion / static
' Blocking mode (blocking parameter):
Const VT_SOUND_BLOCKING   = 1       ' wait for note to finish, keep window alive (default)
'    Wait for the note to finish (default).
Const VT_SOUND_BACKGROUND = 0       ' queue and return immediately
'    Queue and return immediately. 
'    Use vt_sound_wait to sync.
'
':see
'vt_sound
'vt_sound_wait
'<<<

'>>>
    ':topic vt_beep
    ':short Convenience macro: short 800 Hz beep
    ':group Sound
    'Convenience macro. Plays a short 800 Hz square-
    'wave beep, blocking. Equivalent to calling
    'vt_sound(800, 200).
    'Opt-in: #define VT_USE_SOUND before the include.
    ':syntax
    ' #Define VT_BEEP vt_sound(800, 200)
    ':example
    '' Simple error beep:
    'VT_BEEP
    ':see
    'vt_sound
'<<<

Const _VT_SND_RATE         = 11025   ' sample rate: Hz, unsigned 8-bit mono
Const _VT_SND_QUEUE_CAP    = 220500  ' max queued bytes (~20 seconds at 11025 Hz)
' -----------------------------------------------------------------------------
' vt_internal_sound_state - audio subsystem state (vt_sound extension)
' -----------------------------------------------------------------------------
Type vt_internal_sound_state
    dev    As _VT_DRV_AudioDeviceID   ' 0 = not open
    ready  As Byte
End Type

Dim Shared vt_snd As vt_internal_sound_state

' -----------------------------------------------------------------------------
' vt_internal_sound_init - open SDL audio device
' auto-called by vt_sound on first use
' returns: 0=ok, -1=SDL audio init fail, -2=device open fail
' -----------------------------------------------------------------------------
Private Function vt_internal_sound_init() As Long
    If vt_snd.ready Then Return 0

    If _VT_DRV_InitSubSystem(_VT_DRV_INIT_AUDIO) <> 0 Then Return -1

    Dim want As _VT_DRV_AudioSpec
    Dim got  As _VT_DRV_AudioSpec

    want.freq     = _VT_SND_RATE
    want.format   = _VT_DRV_AUDIO_U8
    want.channels = 1
    want.samples  = 512
    want.callback = 0          ' null -- queue-based, no callback thread

    vt_snd.dev = _VT_DRV_OpenAudioDevice(0, 0, @want, @got, 0)
    If vt_snd.dev = 0 Then
        _VT_DRV_QuitSubSystem(_VT_DRV_INIT_AUDIO)
        Return -2
    End If

    _VT_DRV_PauseAudioDevice(vt_snd.dev, 0)   ' devices start paused -- unpause now
    vt_snd.ready = 1
    Return 0
End Function

' -----------------------------------------------------------------------------
' vt_internal_sound_shutdown - close audio device and quit audio subsystem
' called automatically from vt_internal_shutdown in vt_core.bas
' -----------------------------------------------------------------------------
Private Sub vt_internal_sound_shutdown()
    If vt_snd.ready = 0 Then Exit Sub
    _VT_DRV_CloseAudioDevice(vt_snd.dev)
    _VT_DRV_QuitSubSystem(_VT_DRV_INIT_AUDIO)
    vt_snd.dev   = 0 : vt_snd.ready = 0
End Sub

'>>>
':topic vt_sound
':short Generate and queue a tone (opt-in)
':group Sound
'Generate samples for a tone of the given
'frequency and duration and add them to the
'audio queue. The waveform and blocking behaviour
'are selectable. The audio subsystem initializes
'automatically on the first vt_sound call and
'does not require vt_screen to be open. Pass
'freq = 0 to stop playback and clear the queue
'immediately.
'Opt-in: #define VT_USE_SOUND before the include.
':syntax
Function vt_sound(freq     As Long, _
                  dur_ms   As Long = 200, _
                  wave     As Long = VT_WAVE_SQUARE, _
                  blocking As Long = _
                  VT_SOUND_BLOCKING) As Long
        ':params
        'freq      Frequency in Hz. 0 = stop and clear
        '          the queue immediately.
        'dur_ms    Duration in milliseconds. Default 200.
        'wave      Waveform. One of VT_WAVE_* constants.
        'blocking  VT_SOUND_BLOCKING = wait for note to
        '          finish (window stays alive during wait).
        '          VT_SOUND_BACKGROUND = queue and return.
        ':notes
        'Return values:
        '   0  success
        '  -1  audio init or memory alloc failed
        '  -2  queue cap exceeded, call was skipped
        ':example
        '' Single blocking note:
        'vt_sound(440, 500)
        '
        '' Melody blocking note-by-note:
        'vt_sound(262, 200)
        'vt_sound(330, 200)
        'vt_sound(392, 400)
        '
        '' Same melody in background:
        'vt_sound(262, 200, VT_WAVE_SQUARE, _
        '         VT_SOUND_BACKGROUND)
        'vt_sound(330, 200, VT_WAVE_SQUARE, _
        '         VT_SOUND_BACKGROUND)
        'vt_sound(392, 400, VT_WAVE_SQUARE, _
        '         VT_SOUND_BACKGROUND)
        'vt_print("Playing...")
        'vt_present()
        'vt_sound_wait()
        'vt_shutdown()
        '
        '' Stop playback immediately:
        'vt_sound(0)
        ':see
        'vt_sound_wait
        'vt_beep
        'c_soundconsts
    '<<<

    Dim n_samples  As Long
    Dim n_smp_64   As Longint       ' overflow-safe intermediate for duration calc
    Dim queued     As Ulong
    Dim buf        As Ubyte Ptr
    Dim i          As Long
    Dim period     As Long
    Dim half_p     As Long
    Dim position   As Long
    Dim phase_f    As Double
    Dim lfsr       As Ulong
    Dim lfsr_bit   As Ulong
    Dim lfsr_clk   As Long
    Dim lfsr_timer As Long
    Dim smp        As Ubyte

    ' freq = 0: stop and clear queue
    If freq = 0 Then
        If vt_snd.ready Then _VT_DRV_ClearQueuedAudio(vt_snd.dev)
        Return 0
    End If

    ' freq < 0: invalid, no-op (do NOT clear the queue)
    If freq < 0 Then Return 0

    If vt_internal_sound_init() <> 0 Then Return -1

    ' use LongInt for the multiply to avoid Long overflow on large dur_ms values,
    ' then check against the queue cap before casting back down to Long
    n_smp_64 = Clngint(_VT_SND_RATE) * dur_ms \ 1000
    If n_smp_64 < 1 Then Return 0

    queued = _VT_DRV_GetQueuedAudioSize(vt_snd.dev)
    If Clngint(queued) + n_smp_64 > _VT_SND_QUEUE_CAP Then Return -2

    n_samples = Clng(n_smp_64)

    buf = Allocate(n_samples)
    If buf = 0 Then Return -1

    Select Case wave

        Case VT_WAVE_SQUARE
            period = _VT_SND_RATE \ freq
            If period < 2 Then period = 2
            half_p = period \ 2
            For i = 0 To n_samples - 1
                If (i Mod period) < half_p Then
                    buf[i] = 220
                Else
                    buf[i] = 36
                End If
            Next i

        Case VT_WAVE_TRIANGLE
            period = _VT_SND_RATE \ freq
            If period < 2 Then period = 2
            half_p = period \ 2
            If half_p < 1 Then half_p = 1
            For i = 0 To n_samples - 1
                position = i Mod period
                If position < half_p Then
                    buf[i] = Cubyte(36 + (position * 184) \ half_p)
                Else
                    buf[i] = Cubyte(220 - ((position - half_p) * 184) \ half_p)
                End If
            Next i

        Case VT_WAVE_SINE
            For i = 0 To n_samples - 1
                phase_f = 2.0 * 3.14159265358979 * freq * i / _VT_SND_RATE
                buf[i]  = Cubyte(128 + 110 * Sin(phase_f))
            Next i

        Case VT_WAVE_NOISE
            lfsr_clk   = _VT_SND_RATE \ freq
            If lfsr_clk < 1 Then lfsr_clk = 1
            lfsr       = 1
            lfsr_timer = 0
            smp        = 128
            For i = 0 To n_samples - 1
                lfsr_timer += 1
                If lfsr_timer >= lfsr_clk Then
                    lfsr_timer = 0
                    lfsr_bit   = (lfsr Xor (lfsr Shr 1)) And 1
                    lfsr       = (lfsr Shr 1) Or (lfsr_bit Shl 14)
                    smp        = Cubyte(Iif(lfsr And 1, 220, 36))
                End If
                buf[i] = smp
            Next i

        Case Else
            ' unknown wave type -- fill with silence rather than queuing garbage
            For i = 0 To n_samples - 1
                buf[i] = 128
            Next i

    End Select

    _VT_DRV_QueueAudio(vt_snd.dev, buf, Culng(n_samples))
    Deallocate(buf)

    ' any non-zero blocking value is treated as VT_SOUND_BLOCKING
    If blocking <> 0 Then
        Do
            If _VT_DRV_GetQueuedAudioSize(vt_snd.dev) = 0 Then Exit Do
            If vt_internal.ready Then
                vt_pump()
                If vt_internal_blink_update() Then vt_internal.dirty = 1
                vt_internal_present_if_dirty()
            End If
            Sleep 1, 1
        Loop
    End If

    Return 0
End Function

'>>>
':topic vt_sound_wait
':short Block until the audio queue fully drains
':group Sound
'Block until the audio queue fully drains. The
'sync barrier for sequences queued with
'VT_SOUND_BACKGROUND -- lets you run code while
'a melody plays, then wait for it to finish. The
'window stays alive during the wait. No-op if
'the sound subsystem was never initialized.
'Opt-in: define VT_USE_SOUND before the include.
':syntax
Sub vt_sound_wait()
        ':see
        'vt_sound
    '<<<
    If vt_snd.ready = 0 Then Exit Sub
    Do
        If _VT_DRV_GetQueuedAudioSize(vt_snd.dev) = 0 Then Exit Do
        If vt_internal.ready Then
            vt_pump()
            If vt_internal_blink_update() Then vt_internal.dirty = 1
            vt_internal_present_if_dirty()
        End If
        Sleep 1, 1
    Loop
End Sub

#Undef vt_internal_sound_init
#Undef vt_internal_sound_shutdown
