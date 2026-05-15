' --- constants / scancodes ---
enum
	_VT_DRV_SCANCODE_RETURN = 40
	_VT_DRV_SCANCODE_ESCAPE = 41
	_VT_DRV_SCANCODE_BACKSPACE = 42
	_VT_DRV_SCANCODE_TAB = 43
	_VT_DRV_SCANCODE_SPACE = 44
	_VT_DRV_SCANCODE_F1 = 58
	_VT_DRV_SCANCODE_F2 = 59
	_VT_DRV_SCANCODE_F3 = 60
	_VT_DRV_SCANCODE_F4 = 61
	_VT_DRV_SCANCODE_F5 = 62
	_VT_DRV_SCANCODE_F6 = 63
	_VT_DRV_SCANCODE_F7 = 64
	_VT_DRV_SCANCODE_F8 = 65
	_VT_DRV_SCANCODE_F9 = 66
	_VT_DRV_SCANCODE_F10 = 67
	_VT_DRV_SCANCODE_F11 = 68
	_VT_DRV_SCANCODE_F12 = 69
	_VT_DRV_SCANCODE_INSERT = 73
	_VT_DRV_SCANCODE_HOME = 74
	_VT_DRV_SCANCODE_PAGEUP = 75
	_VT_DRV_SCANCODE_DELETE = 76
	_VT_DRV_SCANCODE_END = 77
	_VT_DRV_SCANCODE_PAGEDOWN = 78
	_VT_DRV_SCANCODE_RIGHT = 79
	_VT_DRV_SCANCODE_LEFT = 80
	_VT_DRV_SCANCODE_DOWN = 81
	_VT_DRV_SCANCODE_UP = 82
	_VT_DRV_SCANCODE_KP_ENTER = 88
	_VT_DRV_SCANCODE_LCTRL = 224
	_VT_DRV_SCANCODE_LSHIFT = 225
	_VT_DRV_SCANCODE_LALT = 226
	_VT_DRV_SCANCODE_LGUI = 227
	_VT_DRV_SCANCODE_RCTRL = 228
	_VT_DRV_SCANCODE_RSHIFT = 229
	_VT_DRV_SCANCODE_RALT = 230
	_VT_DRV_SCANCODE_RGUI = 231
end enum

' --- event types ---
enum
    _VT_DRV_QUIT_           = &h100
    _VT_DRV_WINDOWEVENT     = &h200
    _VT_DRV_KEYDOWN         = &h300
    _VT_DRV_KEYUP           = &h301
    _VT_DRV_TEXTINPUT       = &h303
	_VT_DRV_MOUSEMOTION     = &h400
	_VT_DRV_MOUSEBUTTONDOWN = &h401
	_VT_DRV_MOUSEBUTTONUP   = &h402
    _VT_DRV_MOUSEWHEEL      = &h403
end enum

' --- mouse buttons ---
enum
    _VT_DRV_BUTTON_LEFT     = 1
    _VT_DRV_BUTTON_MIDDLE   = 2
    _VT_DRV_BUTTON_RIGHT    = 3
end enum

' --- keymods / keys ---
enum
	_VT_DRVKMOD_NONE = &h0000
	_VT_DRVKMOD_LSHIFT = &h0001
	_VT_DRVKMOD_RSHIFT = &h0002
	_VT_DRVKMOD_LCTRL = &h0040
	_VT_DRVKMOD_RCTRL = &h0080
	_VT_DRVKMOD_LALT = &h0100
	_VT_DRVKMOD_RALT = &h0200
    _VT_DRVKMOD_CTRL = _VT_DRVKMOD_LCTRL or _VT_DRVKMOD_RCTRL
    _VT_DRVKMOD_SHIFT = _VT_DRVKMOD_LSHIFT or _VT_DRVKMOD_RSHIFT
	_VT_DRVKMOD_ALT = _VT_DRVKMOD_LALT or _VT_DRVKMOD_RALT
end enum

Const _VT_DRVK_a = asc("a")
Const _VT_DRVK_z = asc("z")

' --- bool / enable ---
enum
	_VT_DRV_FALSE = 0
	_VT_DRV_TRUE = 1
end enum
const _VT_DRV_DISABLE = 0
const _VT_DRV_ENABLE = 1

' --- init flags ---
const _VT_DRV_INIT_AUDIO = &h00000010u
const _VT_DRV_INIT_VIDEO = &h00000020u

' --- window flags / positions / events ---
enum
	_VT_DRV_WINDOW_FULLSCREEN = &h00000001
	'_VT_DRV_WINDOW_OPENGL = &h00000002
	_VT_DRV_WINDOW_SHOWN = &h00000004
	'_VT_DRV_WINDOW_HIDDEN = &h00000008
	'_VT_DRV_WINDOW_BORDERLESS = &h00000010
	_VT_DRV_WINDOW_RESIZABLE = &h00000020
	'_VT_DRV_WINDOW_MINIMIZED = &h00000040
	'_VT_DRV_WINDOW_MAXIMIZED = &h00000080
	'_VT_DRV_WINDOW_INPUT_GRABBED = &h00000100
	'_VT_DRV_WINDOW_INPUT_FOCUS = &h00000200
	'_VT_DRV_WINDOW_MOUSE_FOCUS = &h00000400
	_VT_DRV_WINDOW_FULLSCREEN_DESKTOP = _VT_DRV_WINDOW_FULLSCREEN or &h00001000
	'_VT_DRV_WINDOW_FOREIGN = &h00000800
	'_VT_DRV_WINDOW_ALLOW_HIGHDPI = &h00002000
	'_VT_DRV_WINDOW_MOUSE_CAPTURE = &h00004000
	'_VT_DRV_WINDOW_ALWAYS_ON_TOP = &h00008000
	'_VT_DRV_WINDOW_SKIP_TASKBAR = &h00010000
	'_VT_DRV_WINDOW_UTILITY = &h00020000
	'_VT_DRV_WINDOW_TOOLTIP = &h00040000
	'_VT_DRV_WINDOW_POPUP_MENU = &h00080000
end enum

'const   _VT_DRV_WINDOWPOS_CENTERED_MASK = &h2FFF0000u
'#define _VT_DRV_WINDOWPOS_CENTERED_       DISPLAY(_X) (_VT_DRV_WINDOWPOS_CENTERED_MASK or (_X))
'#define _VT_DRV_WINDOWPOS_CENTERED        _VT_DRV_WINDOWPOS_CENTERED_DISPLAY(0)
Const _VT_DRV_WINDOWPOS_CENTERED    = &h2FFF0000u
Const _VT_DRV_WINDOWEVENT_RESIZED   = 5

' --- renderer flags ---
enum
	_VT_DRV_RENDERER_SOFTWARE      = &h00000001
	_VT_DRV_RENDERER_ACCELERATED   = &h00000002
	_VT_DRV_RENDERER_PRESENTVSYNC  = &h00000004
	'_VT_DRV_RENDERER_TARGETTEXTURE = &h00000008
end enum

' --- hints ---
Const _VT_DRV_HINT_RENDER_SCALE_QUALITY = "SDL_RENDER_SCALE_QUALITY"

' --- pixel / texture ---
enum
	_VT_DRV_PIXELTYPE_UNKNOWN
	_VT_DRV_PIXELTYPE_INDEX1
	_VT_DRV_PIXELTYPE_INDEX4
	_VT_DRV_PIXELTYPE_INDEX8
	_VT_DRV_PIXELTYPE_PACKED8
	_VT_DRV_PIXELTYPE_PACKED16
	_VT_DRV_PIXELTYPE_PACKED32
	_VT_DRV_PIXELTYPE_ARRAYU8  = 7
	_VT_DRV_PIXELTYPE_ARRAYU16
	_VT_DRV_PIXELTYPE_ARRAYU32
	_VT_DRV_PIXELTYPE_ARRAYF16
	_VT_DRV_PIXELTYPE_ARRAYF32
end enum
enum
	_VT_DRV_PACKEDORDER_NONE = 0
	_VT_DRV_PACKEDORDER_XRGB = 1
	_VT_DRV_PACKEDORDER_RGBX = 2
	_VT_DRV_PACKEDORDER_ARGB = 3
	_VT_DRV_PACKEDORDER_RGBA = 4
	_VT_DRV_PACKEDORDER_XBGR = 5
	_VT_DRV_PACKEDORDER_BGRX = 6
	_VT_DRV_PACKEDORDER_ABGR = 7
	_VT_DRV_PACKEDORDER_BGRA = 8
end enum
enum
	_VT_DRV_PACKEDLAYOUT_NONE
	_VT_DRV_PACKEDLAYOUT_332
	_VT_DRV_PACKEDLAYOUT_4444
	_VT_DRV_PACKEDLAYOUT_1555
	_VT_DRV_PACKEDLAYOUT_5551
	_VT_DRV_PACKEDLAYOUT_565
	_VT_DRV_PACKEDLAYOUT_8888    = 6
	_VT_DRV_PACKEDLAYOUT_2101010
	_VT_DRV_PACKEDLAYOUT_1010102
end enum
enum
	SDL_ARRAYORDER_NONE
	SDL_ARRAYORDER_RGB   = 1
	SDL_ARRAYORDER_RGBA
	SDL_ARRAYORDER_ARGB
	SDL_ARRAYORDER_BGR
	SDL_ARRAYORDER_BGRA
	SDL_ARRAYORDER_ABGR
end enum
#define _VT_DRV_DEFINE_PIXELFORMAT(type, order, layout, bits, bytes) ((((((1 shl 28) or ((type) shl 24)) or ((order) shl 20)) or ((layout) shl 16)) or ((bits) shl 8)) or ((bytes) shl 0))
_VT_DRV_PIXELFORMAT_RGBA8888 = _VT_DRV_DEFINE_PIXELFORMAT(_VT_DRV_PIXELTYPE_PACKED32, _VT_DRV_PACKEDORDER_RGBA, _VT_DRV_PACKEDLAYOUT_8888, 32, 4)
_VT_DRV_PIXELFORMAT_RGB24    = _VT_DRV_DEFINE_PIXELFORMAT(_VT_DRV_PIXELTYPE_ARRAYU8,  _VT_DRV_ARRAYORDER_RGB, 0, 24, 3)
Const   _VT_DRV_TEXTUREACCESS_TARGET = 2
Const   _VT_DRV_BLENDMODE_BLEND = &h00000001

' --- audio ---
Const   _VT_DRV_AUDIO_U8 = &h0008

' --- types ---
Type _VT_DRV_Texture       As _VT_DRV_Texture ptr
Type _VT_DRV_Window        As _VT_DRV_Window ptr
Type _VT_DRV_Renderer      As _VT_DRV_Renderer ptr
Type _VT_DRV_Event         As _VT_DRV_Event ptr
Type _VT_DRV_Keymod        As _VT_DRV_Keymod ptr
Type _VT_DRV_Rect          As _VT_DRV_Rect ptr
Type _VT_DRV_Surface       As _VT_DRV_Surface ptr
Type _VT_DRV_PixelFormat   As _VT_DRV_PixelFormat ptr
Type _VT_DRV_AudioDeviceID As _VT_DRV_AudioDeviceID ptr
Type _VT_DRV_AudioSpec     As _VT_DRV_AudioSpec ptr

' --- function / sub declarations ---
'Extern "C"
Declare Function _VT_DRV_LoadBMP               ( pzFile as zstring ptr ) As _VT_DRV_Surface ptr
Declare Function _VT_DRV_GetTicks              () As ULong
Declare Sub      _VT_DRV_RenderGetScale        (renderer As _VT_DRV_Renderer Ptr, scaleX As Single Ptr, scaleY As Single Ptr)
Declare Function _VT_DRV_GetRendererOutputSize (renderer As _VT_DRV_Renderer Ptr, w As Long Ptr, h As Long Ptr) As Long
Declare Function _VT_DRV_PollEvent             (evt As _VT_DRV_Event Ptr) As Long
Declare Function _VT_DRV_GetModState           () As _VT_DRV_Keymod
Declare Sub      _VT_DRV_DestroyTexture        (texture As _VT_DRV_Texture Ptr)
Declare Sub      _VT_DRV_DestroyRenderer       (renderer As _VT_DRV_Renderer Ptr)
Declare Sub      _VT_DRV_DestroyWindow         (wnd As _VT_DRV_Window Ptr)
Declare Function _VT_DRV_Init                  (flags As ULong) As Long
Declare Sub      _VT_DRV_Quit                  ()
Declare Function _VT_DRV_CreateWindow          (title As ZString Ptr, x As Long, y As Long, w As Long, h As Long, flags As ULong) As _VT_DRV_Window Ptr
Declare Function _VT_DRV_SetWindowFullscreen   (wnd As _VT_DRV_Window Ptr, flags As ULong) As Long
Declare Sub      _VT_DRV_MaximizeWindow        (wnd As _VT_DRV_Window Ptr)
Declare Function _VT_DRV_CreateRenderer        (wnd As _VT_DRV_Window Ptr, idx As Long, flags As ULong) As _VT_DRV_Renderer Ptr
Declare Function _VT_DRV_SetHint               (nm As ZString Ptr, vl As ZString Ptr) As Long
Declare Function _VT_DRV_RenderSetLogicalSize  (renderer As _VT_DRV_Renderer Ptr, w As Long, h As Long) As Long
Declare Function _VT_DRV_RenderSetIntegerScale (renderer As _VT_DRV_Renderer Ptr, enable As Long) As Long
Declare Function _VT_DRV_CreateTexture         (renderer As _VT_DRV_Renderer Ptr, fmt As ULong, access As Long, w As Long, h As Long) As _VT_DRV_Texture Ptr
Declare Function _VT_DRV_SetTextureBlendMode   (texture As _VT_DRV_Texture Ptr, blendMode As Long) As Long
Declare Function _VT_DRV_SetRenderTarget       (renderer As _VT_DRV_Renderer Ptr, texture As _VT_DRV_Texture Ptr) As Long
Declare Function _VT_DRV_SetRenderDrawColor    (renderer As _VT_DRV_Renderer Ptr, r As UByte, g As UByte, b As UByte, a As UByte) As Long
Declare Function _VT_DRV_RenderClear           (renderer As _VT_DRV_Renderer Ptr) As Long
Declare Function _VT_DRV_SetTextureColorMod    (texture As _VT_DRV_Texture Ptr, r As UByte, g As UByte, b As UByte) As Long
Declare Function _VT_DRV_RenderFillRect        (renderer As _VT_DRV_Renderer Ptr, rect As _VT_DRV_Rect Ptr) As Long
Declare Function _VT_DRV_RenderCopy            (renderer As _VT_DRV_Renderer Ptr, texture As _VT_DRV_Texture Ptr, srcrect As _VT_DRV_Rect Ptr, dstrect As _VT_DRV_Rect Ptr) As Long
Declare Sub      _VT_DRV_RenderPresent         (renderer As _VT_DRV_Renderer Ptr)
Declare Sub      _VT_DRV_SetWindowTitle        (wnd As _VT_DRV_Window Ptr, title As ZString Ptr)
Declare Function _VT_DRV_GetKeyboardState      (numkeys As Long Ptr) As UByte Ptr
Declare Function _VT_DRV_GetClipboardText      () As ZString Ptr
Declare Sub      _VT_DRV_free                  (mem As Any Ptr)
Declare Sub      _VT_DRV_SetWindowGrab         (wnd As _VT_DRV_Window Ptr, grabbed As Long)
Declare Sub      _VT_DRV_SetWindowMinimumSize  (wnd As _VT_DRV_Window Ptr, min_w As Long, min_h As Long)
Declare Sub      _VT_DRV_SetWindowMaximumSize  (wnd As _VT_DRV_Window Ptr, max_w As Long, max_h As Long)
Declare Sub      _VT_DRV_GetWindowSize         (wnd As _VT_DRV_Window Ptr, w As Long Ptr, h As Long Ptr)
Declare Sub      _VT_DRV_SetWindowSize         (wnd As _VT_DRV_Window Ptr, w As Long, h As Long)
Declare Function _VT_DRV_ShowCursor            (toggle As Long) As Long
Declare Function _VT_DRV_GetMouseState         (x As Long Ptr, y As Long Ptr) As ULong
Declare Function _VT_DRV_SetClipboardText      (txt As ZString Ptr) As Long
Declare Function _VT_DRV_CreateRGBSurface      (flags As ULong, w As Long, h As Long, depth As Long, rmask As ULong, gmask As ULong, bmask As ULong, amask As ULong) As _VT_DRV_Surface Ptr
Declare Function _VT_DRV_LockSurface           (surface As _VT_DRV_Surface Ptr) As Long
Declare Sub      _VT_DRV_UnlockSurface         (surface As _VT_DRV_Surface Ptr)
Declare Function _VT_DRV_CreateTextureFromSurface (renderer As _VT_DRV_Renderer Ptr, surface As _VT_DRV_Surface Ptr) As _VT_DRV_Texture Ptr
Declare Sub      _VT_DRV_FreeSurface           (surface As _VT_DRV_Surface Ptr)
Declare Function _VT_DRV_AllocFormat           (pixel_format As ULong)              As _VT_DRV_PixelFormat Ptr
Declare Function _VT_DRV_ConvertSurface        (src As _VT_DRV_Surface Ptr, pixfmt As _VT_DRV_PixelFormat Ptr, flags As ULong) As _VT_DRV_Surface Ptr
Declare Sub      _VT_DRV_FreeFormat            (pixfmt As _VT_DRV_PixelFormat Ptr)
Declare Function _VT_DRV_InitSubSystem         (flags As ULong) As Long
Declare Function _VT_DRV_OpenAudioDevice       (device As ZString Ptr, iscapture As Long, desired As _VT_DRV_AudioSpec Ptr, obtained As _VT_DRV_AudioSpec Ptr, allowed_changes As Long) As _VT_DRV_AudioDeviceID
Declare Sub      _VT_DRV_QuitSubsystem         (flags As ULong)
Declare Sub      _VT_DRV_PauseAudioDevice      (dev As _VT_DRV_AudioDeviceID, pause_on As Long)
Declare Sub      _VT_DRV_CloseAudioDevice      (dev As _VT_DRV_AudioDeviceID)
Declare Function _VT_DRV_ClearQueuedAudio      (dev As _VT_DRV_AudioDeviceID) As Long
Declare Function _VT_DRV_QueueAudio            (dev As _VT_DRV_AudioDeviceID, data As Any Ptr, sz As ULong) As Long
Declare Function _VT_DRV_GetQueuedAudioSize    (dev As _VT_DRV_AudioDeviceID) As ULong
'End Extern