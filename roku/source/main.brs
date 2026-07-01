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
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    screen.CreateScene("ScreensaverScene")
    screen.show()

    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
