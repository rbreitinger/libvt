#Include Once "SDL2/sdl.bi"

' --- constants / scancodes ---
#define DRV_SCANCODE_F1               SDL_SCANCODE_F1
#define DRV_SCANCODE_F2               SDL_SCANCODE_F2
#define DRV_SCANCODE_F3               SDL_SCANCODE_F3
#define DRV_SCANCODE_F4               SDL_SCANCODE_F4
#define DRV_SCANCODE_F5               SDL_SCANCODE_F5
#define DRV_SCANCODE_F6               SDL_SCANCODE_F6
#define DRV_SCANCODE_F7               SDL_SCANCODE_F7
#define DRV_SCANCODE_F8               SDL_SCANCODE_F8
#define DRV_SCANCODE_F9               SDL_SCANCODE_F9
#define DRV_SCANCODE_F10              SDL_SCANCODE_F10
#define DRV_SCANCODE_F11              SDL_SCANCODE_F11
#define DRV_SCANCODE_F12              SDL_SCANCODE_F12
#define DRV_SCANCODE_UP               SDL_SCANCODE_UP
#define DRV_SCANCODE_DOWN             SDL_SCANCODE_DOWN
#define DRV_SCANCODE_LEFT             SDL_SCANCODE_LEFT
#define DRV_SCANCODE_RIGHT            SDL_SCANCODE_RIGHT
#define DRV_SCANCODE_HOME             SDL_SCANCODE_HOME
#define DRV_SCANCODE_END              SDL_SCANCODE_END
#define DRV_SCANCODE_PAGEUP           SDL_SCANCODE_PAGEUP
#define DRV_SCANCODE_PAGEDOWN         SDL_SCANCODE_PAGEDOWN
#define DRV_SCANCODE_INSERT           SDL_SCANCODE_INSERT
#define DRV_SCANCODE_DELETE           SDL_SCANCODE_DELETE
#define DRV_SCANCODE_ESCAPE           SDL_SCANCODE_ESCAPE
#define DRV_SCANCODE_RETURN           SDL_SCANCODE_RETURN
#define DRV_SCANCODE_KP_ENTER         SDL_SCANCODE_KP_ENTER
#define DRV_SCANCODE_BACKSPACE        SDL_SCANCODE_BACKSPACE
#define DRV_SCANCODE_TAB              SDL_SCANCODE_TAB
#define DRV_SCANCODE_SPACE            SDL_SCANCODE_SPACE
#define DRV_SCANCODE_LSHIFT           SDL_SCANCODE_LSHIFT
#define DRV_SCANCODE_RSHIFT           SDL_SCANCODE_RSHIFT
#define DRV_SCANCODE_LCTRL            SDL_SCANCODE_LCTRL
#define DRV_SCANCODE_RCTRL            SDL_SCANCODE_RCTRL
#define DRV_SCANCODE_LALT             SDL_SCANCODE_LALT
#define DRV_SCANCODE_RALT             SDL_SCANCODE_RALT
#define DRV_SCANCODE_LGUI             SDL_SCANCODE_LGUI
#define DRV_SCANCODE_RGUI             SDL_SCANCODE_RGUI

' --- event types ---
#define DRV_KEYDOWN                   SDL_KEYDOWN
#define DRV_KEYUP                     SDL_KEYUP
#define DRV_TEXTINPUT                 SDL_TEXTINPUT
#define DRV_WINDOWEVENT               SDL_WINDOWEVENT
#define DRV_MOUSEMOTION               SDL_MOUSEMOTION
#define DRV_MOUSEBUTTONDOWN           SDL_MOUSEBUTTONDOWN
#define DRV_MOUSEBUTTONUP             SDL_MOUSEBUTTONUP
#define DRV_MOUSEWHEEL                SDL_MOUSEWHEEL

' --- enum value (not a function!) ---
#define DRV_Quit_                     SDL_QUIT_

' --- mouse buttons ---
#define DRV_BUTTON_LEFT               SDL_BUTTON_LEFT
#define DRV_BUTTON_MIDDLE             SDL_BUTTON_MIDDLE
#define DRV_BUTTON_RIGHT              SDL_BUTTON_RIGHT

' --- keymods / keys ---
#define DRVKMOD_SHIFT                 KMOD_SHIFT
#define DRVKMOD_CTRL                  KMOD_CTRL
#define DRVKMOD_ALT                   KMOD_ALT
#define DRVK_a                        SDLK_a
#define DRVK_z                        SDLK_z

' --- bool / enable ---
#define DRV_TRUE                      SDL_TRUE
#define DRV_FALSE                     SDL_FALSE
#define DRV_DISABLE                   SDL_DISABLE
#define DRV_ENABLE                    SDL_ENABLE

' --- init flags ---
#define DRV_INIT_VIDEO                SDL_INIT_VIDEO
#define DRV_INIT_AUDIO                SDL_INIT_AUDIO

' --- window flags / positions / events ---
#define DRV_WINDOW_SHOWN              SDL_WINDOW_SHOWN
#define DRV_WINDOW_RESIZABLE          SDL_WINDOW_RESIZABLE
#define DRV_WINDOW_FULLSCREEN         SDL_WINDOW_FULLSCREEN
#define DRV_WINDOW_FULLSCREEN_DESKTOP SDL_WINDOW_FULLSCREEN_DESKTOP
#define DRV_WINDOWPOS_CENTERED        SDL_WINDOWPOS_CENTERED
#define DRV_WINDOWEVENT_RESIZED       SDL_WINDOWEVENT_RESIZED

' --- renderer flags ---
#define DRV_RENDERER_ACCELERATED      SDL_RENDERER_ACCELERATED
#define DRV_RENDERER_PRESENTVSYNC     SDL_RENDERER_PRESENTVSYNC

' --- hints ---
#define DRV_HINT_RENDER_SCALE_QUALITY SDL_HINT_RENDER_SCALE_QUALITY

' --- pixel / texture ---
#define DRV_PIXELFORMAT_RGBA8888      SDL_PIXELFORMAT_RGBA8888
#define DRV_PIXELFORMAT_RGB24         SDL_PIXELFORMAT_RGB24
#define DRV_TEXTUREACCESS_TARGET      SDL_TEXTUREACCESS_TARGET
#define DRV_BLENDMODE_BLEND           SDL_BLENDMODE_BLEND

' --- audio ---
#define DRV_AUDIO_U8                  AUDIO_U8

' --- types ---
Type DRV_Texture       As SDL_Texture
Type DRV_Window        As SDL_Window
Type DRV_Renderer      As SDL_Renderer
Type DRV_Event         As SDL_Event
Type DRV_Keymod        As SDL_Keymod
Type DRV_Rect          As SDL_Rect
Type DRV_Surface       As SDL_Surface
Type DRV_PixelFormat   As SDL_PixelFormat
Type DRV_AudioDeviceID As SDL_AudioDeviceID
Type DRV_AudioSpec     As SDL_AudioSpec

' --- SDL_LoadBMP is a C macro wrapping SDL_LoadBMP_RW — cannot use Alias ---
#define DRV_LoadBmp                   SDL_LoadBmp

' --- function / sub declarations ---
Extern "C"

Declare Function DRV_GetTicks              Alias "SDL_GetTicks"              ()                                                                                                                As ULong
Declare Sub      DRV_RenderGetScale        Alias "SDL_RenderGetScale"        (renderer As DRV_Renderer Ptr, scaleX As Single Ptr, scaleY As Single Ptr)
Declare Function DRV_GetRendererOutputSize Alias "SDL_GetRendererOutputSize" (renderer As DRV_Renderer Ptr, w As Long Ptr, h As Long Ptr)                                                    As Long
Declare Function DRV_PollEvent             Alias "SDL_PollEvent"             (evt As DRV_Event Ptr)                                                                                           As Long
Declare Function DRV_GetModState           Alias "SDL_GetModState"           ()                                                                                                               As DRV_Keymod
Declare Sub      DRV_DestroyTexture        Alias "SDL_DestroyTexture"        (texture As DRV_Texture Ptr)
Declare Sub      DRV_DestroyRenderer       Alias "SDL_DestroyRenderer"       (renderer As DRV_Renderer Ptr)
Declare Sub      DRV_DestroyWindow         Alias "SDL_DestroyWindow"         (wnd As DRV_Window Ptr)
Declare Function DRV_Init                  Alias "SDL_Init"                  (flags As ULong)                                                                                                 As Long
Declare Sub      DRV_Quit                  Alias "SDL_Quit"                  ()
Declare Function DRV_CreateWindow          Alias "SDL_CreateWindow"          (title As ZString Ptr, x As Long, y As Long, w As Long, h As Long, flags As ULong)                              As DRV_Window Ptr
Declare Function DRV_SetWindowFullscreen   Alias "SDL_SetWindowFullscreen"   (wnd As DRV_Window Ptr, flags As ULong)                                                                         As Long
Declare Sub      DRV_MaximizeWindow        Alias "SDL_MaximizeWindow"        (wnd As DRV_Window Ptr)
Declare Function DRV_CreateRenderer        Alias "SDL_CreateRenderer"        (wnd As DRV_Window Ptr, idx As Long, flags As ULong)                                                            As DRV_Renderer Ptr
Declare Function DRV_SetHint               Alias "SDL_SetHint"               (nm As ZString Ptr, vl As ZString Ptr)                                                                          As Long
Declare Function DRV_RenderSetLogicalSize  Alias "SDL_RenderSetLogicalSize"  (renderer As DRV_Renderer Ptr, w As Long, h As Long)                                                           As Long
Declare Function DRV_RenderSetIntegerScale Alias "SDL_RenderSetIntegerScale" (renderer As DRV_Renderer Ptr, enable As Long)                                                                  As Long
Declare Function DRV_CreateTexture         Alias "SDL_CreateTexture"         (renderer As DRV_Renderer Ptr, fmt As ULong, access As Long, w As Long, h As Long)                             As DRV_Texture Ptr
Declare Function DRV_SetTextureBlendMode   Alias "SDL_SetTextureBlendMode"   (texture As DRV_Texture Ptr, blendMode As Long)                                                                 As Long
Declare Function DRV_SetRenderTarget       Alias "SDL_SetRenderTarget"       (renderer As DRV_Renderer Ptr, texture As DRV_Texture Ptr)                                                     As Long
Declare Function DRV_SetRenderDrawColor    Alias "SDL_SetRenderDrawColor"    (renderer As DRV_Renderer Ptr, r As UByte, g As UByte, b As UByte, a As UByte)                                As Long
Declare Function DRV_RenderClear           Alias "SDL_RenderClear"           (renderer As DRV_Renderer Ptr)                                                                                  As Long
Declare Function DRV_SetTextureColorMod    Alias "SDL_SetTextureColorMod"    (texture As DRV_Texture Ptr, r As UByte, g As UByte, b As UByte)                                              As Long
Declare Function DRV_RenderFillRect        Alias "SDL_RenderFillRect"        (renderer As DRV_Renderer Ptr, rect As DRV_Rect Ptr)                                                           As Long
Declare Function DRV_RenderCopy            Alias "SDL_RenderCopy"            (renderer As DRV_Renderer Ptr, texture As DRV_Texture Ptr, srcrect As DRV_Rect Ptr, dstrect As DRV_Rect Ptr) As Long
Declare Sub      DRV_RenderPresent         Alias "SDL_RenderPresent"         (renderer As DRV_Renderer Ptr)
Declare Sub      DRV_SetWindowTitle        Alias "SDL_SetWindowTitle"        (wnd As DRV_Window Ptr, title As ZString Ptr)
Declare Function DRV_GetKeyboardState      Alias "SDL_GetKeyboardState"      (numkeys As Long Ptr)                                                                                            As UByte Ptr
Declare Function DRV_GetClipboardText      Alias "SDL_GetClipboardText"      ()                                                                                                               As ZString Ptr
Declare Sub      DRV_free                  Alias "SDL_free"                  (mem As Any Ptr)
Declare Sub      DRV_SetWindowGrab         Alias "SDL_SetWindowGrab"         (wnd As DRV_Window Ptr, grabbed As Long)
Declare Function DRV_ShowCursor            Alias "SDL_ShowCursor"            (toggle As Long)                                                                                                 As Long
Declare Function DRV_GetMouseState         Alias "SDL_GetMouseState"         (x As Long Ptr, y As Long Ptr)                                                                                  As ULong
Declare Function DRV_SetClipboardText      Alias "SDL_SetClipboardText"      (txt As ZString Ptr)                                                                                            As Long
Declare Function DRV_CreateRGBSurface      Alias "SDL_CreateRGBSurface"      (flags As ULong, w As Long, h As Long, depth As Long, rmask As ULong, gmask As ULong, bmask As ULong, amask As ULong) As DRV_Surface Ptr
Declare Function DRV_LockSurface           Alias "SDL_LockSurface"           (surface As DRV_Surface Ptr)                                                                                    As Long
Declare Sub      DRV_UnlockSurface         Alias "SDL_UnlockSurface"         (surface As DRV_Surface Ptr)
Declare Function DRV_CreateTextureFromSurface Alias "SDL_CreateTextureFromSurface" (renderer As DRV_Renderer Ptr, surface As DRV_Surface Ptr)                                              As DRV_Texture Ptr
Declare Sub      DRV_FreeSurface           Alias "SDL_FreeSurface"           (surface As DRV_Surface Ptr)
Declare Function DRV_AllocFormat           Alias "SDL_AllocFormat"           (pixel_format As ULong)                                                                                         As DRV_PixelFormat Ptr
Declare Function DRV_ConvertSurface        Alias "SDL_ConvertSurface"        (src As DRV_Surface Ptr, pixfmt As DRV_PixelFormat Ptr, flags As ULong)                                       As DRV_Surface Ptr
Declare Sub      DRV_FreeFormat            Alias "SDL_FreeFormat"            (pixfmt As DRV_PixelFormat Ptr)
Declare Function DRV_InitSubSystem         Alias "SDL_InitSubSystem"         (flags As ULong)                                                                                                As Long
Declare Function DRV_OpenAudioDevice       Alias "SDL_OpenAudioDevice"       (device As ZString Ptr, iscapture As Long, desired As DRV_AudioSpec Ptr, obtained As DRV_AudioSpec Ptr, allowed_changes As Long) As DRV_AudioDeviceID
Declare Sub      DRV_QuitSubsystem         Alias "SDL_QuitSubSystem"         (flags As ULong)
Declare Sub      DRV_PauseAudioDevice      Alias "SDL_PauseAudioDevice"      (dev As DRV_AudioDeviceID, pause_on As Long)
Declare Sub      DRV_CloseAudioDevice      Alias "SDL_CloseAudioDevice"      (dev As DRV_AudioDeviceID)
Declare Function DRV_ClearQueuedAudio      Alias "SDL_ClearQueuedAudio"      (dev As DRV_AudioDeviceID)                                                                                     As Long
Declare Function DRV_QueueAudio            Alias "SDL_QueueAudio"            (dev As DRV_AudioDeviceID, data As Any Ptr, sz As ULong)                                                       As Long
Declare Function DRV_GetQueuedAudioSize    Alias "SDL_GetQueuedAudioSize"    (dev As DRV_AudioDeviceID)                                                                                     As ULong

End Extern