' =============================================================================
' vt.bi - VT Virtual Text Screen Library
' The single include for user projects.
' Usage: #include once "vt/vt.bi"
' =============================================================================

#include once "SDL2/SDL.bi"

#include once "vt_const.bi"
#include once "vt_types.bi"
#include once "vt_font.bi"

' -----------------------------------------------------------------------------
' One-time implementation guard.
' vt_core.bas, vt_print.bas etc. each do: #include once "vt/vt.bi"
' When compiled as part of the library those files define VT_IMPL themselves.
' User projects must NOT define VT_IMPL - it is set automatically.
' -----------------------------------------------------------------------------
#Ifndef VT_IMPL
    #Define VT_IMPL

    ' pull in all implementation modules
    #include once "vt_core.bas"
    #include once "vt_print.bas"

#EndIf
