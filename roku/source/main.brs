' ============================================================
' Global Pulse - screensaver entry point
' ============================================================
' RunScreenSaver() is the ONLY entry point. Roku certification
' requires screensavers to export RunScreenSaver() and NOT
' Main()/RunUserInterface(). It runs as the active saver on idle.
' (To preview during development, temporarily add a Main() that
' calls RunScreenSaver, then remove it before packaging.)
' ============================================================

' Screensavers must export ONLY RunScreenSaver() — Main()/RunUserInterface() are
' prohibited by Roku certification, and the saver takes no user input.
sub RunScreenSaver()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)

    ' Memory monitoring (Roku certification best practice). Some of these APIs
    ' are gated on newer Roku OS, so guard them — they enable on capable devices
    ' and no-op safely on older ones (the saver streams its media, so its
    ' footprint is tiny either way).
    try
        mem = CreateObject("roAppMemoryMonitor")
        mem.SetMessagePort(port)
        mem.EnableMemoryWarningEvent(true)
        mem.GetMemoryLimitPercent()
        mem.GetChannelMemoryLimit()
        mem.GetChannelAvailableMemory()
    catch memErr
    end try
    try
        di = CreateObject("roDeviceInfo")
        di.EnableLowGeneralMemoryEvent(true)
    catch devErr
    end try

    screen.CreateScene("ScreensaverScene")
    screen.show()

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
