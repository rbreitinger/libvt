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
#define _VT_DRV_KEYDOWN                   SDL_KEYDOWN
#define _VT_DRV_KEYUP                     SDL_KEYUP
#define _VT_DRV_TEXTINPUT                 SDL_TEXTINPUT
#define _VT_DRV_WINDOWEVENT               SDL_WINDOWEVENT
#define _VT_DRV_MOUSEMOTION               SDL_MOUSEMOTION
#define _VT_DRV_MOUSEBUTTONDOWN           SDL_MOUSEBUTTONDOWN
#define _VT_DRV_MOUSEBUTTONUP             SDL_MOUSEBUTTONUP
#define _VT_DRV_MOUSEWHEEL                SDL_MOUSEWHEEL

' --- enum value (not a function!) ---
#define _VT_DRV_Quit_                     SDL_QUIT_

' --- mouse buttons ---
#define _VT_DRV_BUTTON_LEFT               SDL_BUTTON_LEFT
#define _VT_DRV_BUTTON_MIDDLE             SDL_BUTTON_MIDDLE
#define _VT_DRV_BUTTON_RIGHT              SDL_BUTTON_RIGHT

' --- keymods / keys ---
#define _VT_DRVKMOD_SHIFT                 KMOD_SHIFT
#define _VT_DRVKMOD_CTRL                  KMOD_CTRL
#define _VT_DRVKMOD_ALT                   KMOD_ALT
#define _VT_DRVK_a                        SDLK_a
#define _VT_DRVK_z                        SDLK_z

' --- bool / enable ---
#define _VT_DRV_TRUE                      SDL_TRUE
#define _VT_DRV_FALSE                     SDL_FALSE
#define _VT_DRV_DISABLE                   SDL_DISABLE
#define _VT_DRV_ENABLE                    SDL_ENABLE

' --- init flags ---
#define _VT_DRV_INIT_VIDEO                SDL_INIT_VIDEO
#define _VT_DRV_INIT_AUDIO                SDL_INIT_AUDIO

' --- window flags / positions / events ---
#define _VT_DRV_WINDOW_SHOWN              SDL_WINDOW_SHOWN
#define _VT_DRV_WINDOW_RESIZABLE          SDL_WINDOW_RESIZABLE
#define _VT_DRV_WINDOW_FULLSCREEN         SDL_WINDOW_FULLSCREEN
#define _VT_DRV_WINDOW_FULLSCREEN_DESKTOP SDL_WINDOW_FULLSCREEN_DESKTOP
#define _VT_DRV_WINDOWPOS_CENTERED        SDL_WINDOWPOS_CENTERED
#define _VT_DRV_WINDOWEVENT_RESIZED       SDL_WINDOWEVENT_RESIZED

' --- renderer flags ---
#define _VT_DRV_RENDERER_SOFTWARE         SDL_RENDERER_SOFTWARE
#define _VT_DRV_RENDERER_ACCELERATED      SDL_RENDERER_ACCELERATED
#define _VT_DRV_RENDERER_PRESENTVSYNC     SDL_RENDERER_PRESENTVSYNC

' --- hints ---
#define _VT_DRV_HINT_RENDER_SCALE_QUALITY SDL_HINT_RENDER_SCALE_QUALITY

' --- pixel / texture ---
#define _VT_DRV_PIXELFORMAT_RGBA8888      SDL_PIXELFORMAT_RGBA8888
#define _VT_DRV_PIXELFORMAT_RGB24         SDL_PIXELFORMAT_RGB24
#define _VT_DRV_TEXTUREACCESS_TARGET      SDL_TEXTUREACCESS_TARGET
#define _VT_DRV_BLENDMODE_BLEND           SDL_BLENDMODE_BLEND

' --- audio ---
#define _VT_DRV_AUDIO_U8                  AUDIO_U8

' --- types ---
Type _VT_DRV_Texture       As SDL_Texture
Type _VT_DRV_Window        As SDL_Window
Type _VT_DRV_Renderer      As SDL_Renderer
Type _VT_DRV_Event         As SDL_Event
Type _VT_DRV_Keymod        As SDL_Keymod
Type _VT_DRV_Rect          As SDL_Rect
Type _VT_DRV_Surface       As SDL_Surface
Type _VT_DRV_PixelFormat   As SDL_PixelFormat
Type _VT_DRV_AudioDeviceID As SDL_AudioDeviceID
Type _VT_DRV_AudioSpec     As SDL_AudioSpec

' --- SDL_LoadBMP is a C macro wrapping SDL_LoadBMP_RW — cannot use Alias ---
#define _VT_DRV_LoadBmp                   SDL_LoadBmp

' --- function / sub declarations ---
Extern "C"

Declare Function _VT_DRV_GetTicks              Alias "SDL_GetTicks"              ()                                                                                                                As ULong
Declare Sub      _VT_DRV_RenderGetScale        Alias "SDL_RenderGetScale"        (renderer As _VT_DRV_Renderer Ptr, scaleX As Single Ptr, scaleY As Single Ptr)
Declare Function _VT_DRV_GetRendererOutputSize Alias "SDL_GetRendererOutputSize" (renderer As _VT_DRV_Renderer Ptr, w As Long Ptr, h As Long Ptr)                                                    As Long
Declare Function _VT_DRV_PollEvent             Alias "SDL_PollEvent"             (evt As _VT_DRV_Event Ptr)                                                                                           As Long
Declare Function _VT_DRV_GetModState           Alias "SDL_GetModState"           ()                                                                                                               As _VT_DRV_Keymod
Declare Sub      _VT_DRV_DestroyTexture        Alias "SDL_DestroyTexture"        (texture As _VT_DRV_Texture Ptr)
Declare Sub      _VT_DRV_DestroyRenderer       Alias "SDL_DestroyRenderer"       (renderer As _VT_DRV_Renderer Ptr)
Declare Sub      _VT_DRV_DestroyWindow         Alias "SDL_DestroyWindow"         (wnd As _VT_DRV_Window Ptr)
Declare Function _VT_DRV_Init                  Alias "SDL_Init"                  (flags As ULong)                                                                                                 As Long
Declare Sub      _VT_DRV_Quit                  Alias "SDL_Quit"                  ()
Declare Function _VT_DRV_CreateWindow          Alias "SDL_CreateWindow"          (title As ZString Ptr, x As Long, y As Long, w As Long, h As Long, flags As ULong)                              As _VT_DRV_Window Ptr
Declare Function _VT_DRV_SetWindowFullscreen   Alias "SDL_SetWindowFullscreen"   (wnd As _VT_DRV_Window Ptr, flags As ULong)                                                                         As Long
Declare Sub      _VT_DRV_MaximizeWindow        Alias "SDL_MaximizeWindow"        (wnd As _VT_DRV_Window Ptr)
Declare Function _VT_DRV_CreateRenderer        Alias "SDL_CreateRenderer"        (wnd As _VT_DRV_Window Ptr, idx As Long, flags As ULong)                                                            As _VT_DRV_Renderer Ptr
Declare Function _VT_DRV_SetHint               Alias "SDL_SetHint"               (nm As ZString Ptr, vl As ZString Ptr)                                                                          As Long
Declare Function _VT_DRV_RenderSetLogicalSize  Alias "SDL_RenderSetLogicalSize"  (renderer As _VT_DRV_Renderer Ptr, w As Long, h As Long)                                                           As Long
Declare Function _VT_DRV_RenderSetIntegerScale Alias "SDL_RenderSetIntegerScale" (renderer As _VT_DRV_Renderer Ptr, enable As Long)                                                                  As Long
Declare Function _VT_DRV_CreateTexture         Alias "SDL_CreateTexture"         (renderer As _VT_DRV_Renderer Ptr, fmt As ULong, access As Long, w As Long, h As Long)                             As _VT_DRV_Texture Ptr
Declare Function _VT_DRV_SetTextureBlendMode   Alias "SDL_SetTextureBlendMode"   (texture As _VT_DRV_Texture Ptr, blendMode As Long)                                                                 As Long
Declare Function _VT_DRV_SetRenderTarget       Alias "SDL_SetRenderTarget"       (renderer As _VT_DRV_Renderer Ptr, texture As _VT_DRV_Texture Ptr)                                                     As Long
Declare Function _VT_DRV_SetRenderDrawColor    Alias "SDL_SetRenderDrawColor"    (renderer As _VT_DRV_Renderer Ptr, r As UByte, g As UByte, b As UByte, a As UByte)                                As Long
Declare Function _VT_DRV_RenderClear           Alias "SDL_RenderClear"           (renderer As _VT_DRV_Renderer Ptr)                                                                                  As Long
Declare Function _VT_DRV_SetTextureColorMod    Alias "SDL_SetTextureColorMod"    (texture As _VT_DRV_Texture Ptr, r As UByte, g As UByte, b As UByte)                                              As Long
Declare Function _VT_DRV_RenderFillRect        Alias "SDL_RenderFillRect"        (renderer As _VT_DRV_Renderer Ptr, rect As _VT_DRV_Rect Ptr)                                                           As Long
Declare Function _VT_DRV_RenderCopy            Alias "SDL_RenderCopy"            (renderer As _VT_DRV_Renderer Ptr, texture As _VT_DRV_Texture Ptr, srcrect As _VT_DRV_Rect Ptr, dstrect As _VT_DRV_Rect Ptr) As Long
Declare Sub      _VT_DRV_RenderPresent         Alias "SDL_RenderPresent"         (renderer As _VT_DRV_Renderer Ptr)
Declare Sub      _VT_DRV_SetWindowTitle        Alias "SDL_SetWindowTitle"        (wnd As _VT_DRV_Window Ptr, title As ZString Ptr)
Declare Function _VT_DRV_GetKeyboardState      Alias "SDL_GetKeyboardState"      (numkeys As Long Ptr)                                                                                            As UByte Ptr
Declare Function _VT_DRV_GetClipboardText      Alias "SDL_GetClipboardText"      ()                                                                                                               As ZString Ptr
Declare Sub      _VT_DRV_free                  Alias "SDL_free"                  (mem As Any Ptr)
Declare Sub      _VT_DRV_SetWindowGrab         Alias "SDL_SetWindowGrab"         (wnd As _VT_DRV_Window Ptr, grabbed As Long)
Declare Sub      _VT_DRV_SetWindowMinimumSize   Alias "SDL_SetWindowMinimumSize"   (wnd As _VT_DRV_Window Ptr, min_w As Long, min_h As Long)
Declare Sub      _VT_DRV_SetWindowMaximumSize   Alias "SDL_SetWindowMaximumSize"   (wnd As _VT_DRV_Window Ptr, max_w As Long, max_h As Long)
Declare Sub      _VT_DRV_GetWindowSize Alias "SDL_GetWindowSize" (wnd As _VT_DRV_Window Ptr, w As Long Ptr, h As Long Ptr)
Declare Sub      _VT_DRV_SetWindowSize          Alias "SDL_SetWindowSize"          (wnd As _VT_DRV_Window Ptr, w As Long, h As Long)
Declare Function _VT_DRV_ShowCursor            Alias "SDL_ShowCursor"            (toggle As Long)                                                                                                 As Long
Declare Function _VT_DRV_GetMouseState         Alias "SDL_GetMouseState"         (x As Long Ptr, y As Long Ptr)                                                                                  As ULong
Declare Function _VT_DRV_SetClipboardText      Alias "SDL_SetClipboardText"      (txt As ZString Ptr)                                                                                            As Long
Declare Function _VT_DRV_CreateRGBSurface      Alias "SDL_CreateRGBSurface"      (flags As ULong, w As Long, h As Long, depth As Long, rmask As ULong, gmask As ULong, bmask As ULong, amask As ULong) As _VT_DRV_Surface Ptr
Declare Function _VT_DRV_LockSurface           Alias "SDL_LockSurface"           (surface As _VT_DRV_Surface Ptr)                                                                                    As Long
Declare Sub      _VT_DRV_UnlockSurface         Alias "SDL_UnlockSurface"         (surface As _VT_DRV_Surface Ptr)
Declare Function _VT_DRV_CreateTextureFromSurface Alias "SDL_CreateTextureFromSurface" (renderer As _VT_DRV_Renderer Ptr, surface As _VT_DRV_Surface Ptr)                                              As _VT_DRV_Texture Ptr
Declare Sub      _VT_DRV_FreeSurface           Alias "SDL_FreeSurface"           (surface As _VT_DRV_Surface Ptr)
Declare Function _VT_DRV_AllocFormat           Alias "SDL_AllocFormat"           (pixel_format As ULong)                                                                                         As _VT_DRV_PixelFormat Ptr
Declare Function _VT_DRV_ConvertSurface        Alias "SDL_ConvertSurface"        (src As _VT_DRV_Surface Ptr, pixfmt As _VT_DRV_PixelFormat Ptr, flags As ULong)                                       As _VT_DRV_Surface Ptr
Declare Sub      _VT_DRV_FreeFormat            Alias "SDL_FreeFormat"            (pixfmt As _VT_DRV_PixelFormat Ptr)
Declare Function _VT_DRV_InitSubSystem         Alias "SDL_InitSubSystem"         (flags As ULong)                                                                                                As Long
Declare Function _VT_DRV_OpenAudioDevice       Alias "SDL_OpenAudioDevice"       (device As ZString Ptr, iscapture As Long, desired As _VT_DRV_AudioSpec Ptr, obtained As _VT_DRV_AudioSpec Ptr, allowed_changes As Long) As _VT_DRV_AudioDeviceID
Declare Sub      _VT_DRV_QuitSubsystem         Alias "SDL_QuitSubSystem"         (flags As ULong)
Declare Sub      _VT_DRV_PauseAudioDevice      Alias "SDL_PauseAudioDevice"      (dev As _VT_DRV_AudioDeviceID, pause_on As Long)
Declare Sub      _VT_DRV_CloseAudioDevice      Alias "SDL_CloseAudioDevice"      (dev As _VT_DRV_AudioDeviceID)
Declare Function _VT_DRV_ClearQueuedAudio      Alias "SDL_ClearQueuedAudio"      (dev As _VT_DRV_AudioDeviceID)                                                                                     As Long
Declare Function _VT_DRV_QueueAudio            Alias "SDL_QueueAudio"            (dev As _VT_DRV_AudioDeviceID, data As Any Ptr, sz As ULong)                                                       As Long
Declare Function _VT_DRV_GetQueuedAudioSize    Alias "SDL_GetQueuedAudioSize"    (dev As _VT_DRV_AudioDeviceID)                                                                                     As ULong

End Extern