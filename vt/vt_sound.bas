' =============================================================================
' vt_sound.bas : opt-in Sound Extension (not available in VT_TTY!)
' Generates waveform samples and queues them via SDL_QueueAudio.
' =============================================================================

' -----------------------------------------------------------------------------
' Sound waveform constants  (vt_sound wave param)
' -----------------------------------------------------------------------------
Const VT_WAVE_SQUARE   = 0   ' PC speaker / chiptune square wave (default)
Const VT_WAVE_TRIANGLE = 1   ' NES triangle channel -- softer, bass feel
Const VT_WAVE_SINE     = 2   ' pure sine tone
Const VT_WAVE_NOISE    = 3   ' 15-bit LFSR noise -- NES percussion / static

' -----------------------------------------------------------------------------
' Sound blocking constants  (vt_sound blocking param)
' -----------------------------------------------------------------------------
Const VT_SOUND_BLOCKING   = 1   ' wait for note to finish, keep window alive (default)
Const VT_SOUND_BACKGROUND = 0   ' queue and return immediately

' -----------------------------------------------------------------------------
' Sound tuning constants
' -----------------------------------------------------------------------------
Const VT_SND_RATE      = 11025    ' sample rate: Hz, unsigned 8-bit mono
Const VT_SND_QUEUE_CAP = 220500   ' max queued bytes (~20 seconds at 11025 Hz)

#Define VT_BEEP vt_sound(800, 200)

' -----------------------------------------------------------------------------
' vt_internal_sound_state - audio subsystem state (vt_sound extension)
' -----------------------------------------------------------------------------
Type vt_internal_sound_state
    dev    As SDL_AudioDeviceID   ' 0 = not open
    ready  As Byte
End Type

Dim Shared vt_snd As vt_internal_sound_state

' -----------------------------------------------------------------------------
' vt_internal_sound_init - open SDL audio device
' auto-called by vt_sound on first use
' returns: 0=ok, -1=SDL audio init fail, -2=device open fail
' -----------------------------------------------------------------------------
Function vt_internal_sound_init() As Long
    If vt_snd.ready Then Return 0

    If SDL_InitSubSystem(SDL_INIT_AUDIO) <> 0 Then Return -1

    Dim want As SDL_AudioSpec
    Dim got  As SDL_AudioSpec

    want.freq     = VT_SND_RATE
    want.format   = AUDIO_U8
    want.channels = 1
    want.samples  = 512
    want.callback = 0          ' null -- queue-based, no callback thread

    vt_snd.dev = SDL_OpenAudioDevice(0, 0, @want, @got, 0)
    If vt_snd.dev = 0 Then
        SDL_QuitSubSystem(SDL_INIT_AUDIO)
        Return -2
    End If

    SDL_PauseAudioDevice(vt_snd.dev, 0)   ' devices start paused -- unpause now
    vt_snd.ready = 1
    Return 0
End Function

' -----------------------------------------------------------------------------
' vt_internal_sound_shutdown - close audio device and quit audio subsystem
' called automatically from vt_internal_shutdown in vt_core.bas
' -----------------------------------------------------------------------------
Sub vt_internal_sound_shutdown()
    If vt_snd.ready = 0 Then Exit Sub
    SDL_CloseAudioDevice(vt_snd.dev)
    SDL_QuitSubSystem(SDL_INIT_AUDIO)
    vt_snd.dev   = 0
    vt_snd.ready = 0
End Sub

' -----------------------------------------------------------------------------
' vt_sound - generate and queue a tone
'
' returns  : 0=ok, -1=init or alloc fail, -2=queue cap exceeded (call skipped)
'
' note: if vt_screen has not been opened, blocking wait still works correctly --
'       vt_pump exits instantly when vt_internal.ready = 0, Sleep carries the
'       wait, and SDL plays audio on its own thread regardless.
' -----------------------------------------------------------------------------
Function vt_sound(freq     As Long,                   _
                  dur_ms   As Long = 200,              _
                  wave     As Long = VT_WAVE_SQUARE,   _
                  blocking As Long = VT_SOUND_BLOCKING) As Long

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
        If vt_snd.ready Then SDL_ClearQueuedAudio(vt_snd.dev)
        Return 0
    End If

    ' freq < 0: invalid, no-op (do NOT clear the queue)
    If freq < 0 Then Return 0

    If vt_internal_sound_init() <> 0 Then Return -1

    ' use LongInt for the multiply to avoid Long overflow on large dur_ms values,
    ' then check against the queue cap before casting back down to Long
    n_smp_64 = Clngint(VT_SND_RATE) * dur_ms \ 1000
    If n_smp_64 < 1 Then Return 0

    queued = SDL_GetQueuedAudioSize(vt_snd.dev)
    If Clngint(queued) + n_smp_64 > VT_SND_QUEUE_CAP Then Return -2

    n_samples = Clng(n_smp_64)

    buf = Allocate(n_samples)
    If buf = 0 Then Return -1

    Select Case wave

        Case VT_WAVE_SQUARE
            period = VT_SND_RATE \ freq
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
            period = VT_SND_RATE \ freq
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
                phase_f = 2.0 * 3.14159265358979 * freq * i / VT_SND_RATE
                buf[i]  = Cubyte(128 + 110 * Sin(phase_f))
            Next i

        Case VT_WAVE_NOISE
            lfsr_clk   = VT_SND_RATE \ freq
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

    SDL_QueueAudio(vt_snd.dev, buf, Culng(n_samples))
    Deallocate(buf)

    ' any non-zero blocking value is treated as VT_SOUND_BLOCKING
    If blocking <> 0 Then
        Do
            If SDL_GetQueuedAudioSize(vt_snd.dev) = 0 Then Exit Do
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

' -----------------------------------------------------------------------------
' vt_sound_wait - block until the audio queue fully drains
' the sync barrier for VT_SOUND_BACKGROUND sequences
' -----------------------------------------------------------------------------
Sub vt_sound_wait()
    If vt_snd.ready = 0 Then Exit Sub
    Do
        If SDL_GetQueuedAudioSize(vt_snd.dev) = 0 Then Exit Do
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
