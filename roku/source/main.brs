' ============================================================
' Global Pulse - entry points
' ============================================================
' RunScreenSaver() is the screensaver entry point. When a
' sideloaded channel exports this sub, Roku lists it under
' Settings > Screensaver and runs it as the active saver.
'
' Main() is provided so you can ALSO launch the channel
' normally from the Home screen to preview it during
' development. Both spin up the same SceneGraph scene.
' ============================================================

' Screensavers must export ONLY RunScreenSaver() — Main()/RunUserInterface() are
' prohibited by Roku certification, and the saver takes no user input.
sub RunScreenSaver()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("ScreensaverScene")
    screen.show()

    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
