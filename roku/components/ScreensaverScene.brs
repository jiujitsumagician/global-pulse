' ============================================================
' ScreensaverScene.brs  (video-globe edition)
' Smooth globe rotation = a hardware-decoded H.264 loop on a Video
' node. Live markers are projected onto the sphere and synced to
' Video.position (no texture swapping). OK opens a QR overlay.
'
' Projection MUST match tools/render_globe_video.py:
'   render frame i centred on longitude -i*(360/N); the video plays
'   those frames, so at stream time t the centred longitude is
'   -(frac(t/secPerRev))*360, camera tilt gLat0.
' ============================================================

function categoryColor(cat as dynamic) as string
    c = ""
    if cat <> invalid then c = LCase(cat)
    if c = "conflict" then return "0xff5a4dff"
    if c = "politics" then return "0xb98cffff"
    if c = "disaster" then return "0xff9e3dff"
    if c = "news"     then return "0x5fe3ffff"
    if c = "quake"    then return "0xffd23dff"
    if c = "nature"   then return "0x5ce0a0ff"
    if c = "space"    then return "0x8aa6ffff"
    return "0x9fb4c8ff"
end function

sub init()
    ' Transparent scene background so the hardware video plane (the globe)
    ' is never occluded by the graphics plane.
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x00000000"

    ' globe geometry (1080-space): video is 1920x1080; the source render
    ' is 1280x720 with centre (640,326) R=332 tilt 16 -> x1.5 here.
    m.gR    = 498.0
    m.gCX   = 960.0
    m.gCY   = 489.0
    m.gLat0 = 16.0
    m.D2R   = 3.1415926535 / 180.0
    m.secPerRev = 24.0       ' seconds per full revolution in the video loop
    m.curLon0 = 0.0

    ' Nodes.
    m.globeCamera = m.top.findNode("globeCamera")
    m.globeVideo  = m.top.findNode("globeVideo")
    m.markersGroup = m.top.findNode("markersGroup")
    m.highlightGroup = m.top.findNode("highlightGroup")
    m.highlightHalo  = m.top.findNode("highlightHalo")

    m.liveTxt  = m.top.findNode("liveTxt")
    m.evCount  = m.top.findNode("evCount")

    m.cardGroup   = m.top.findNode("cardGroup")
    m.categoryTag = m.top.findNode("categoryTag")
    m.titleLabel  = m.top.findNode("titleLabel")
    m.placeLabel  = m.top.findNode("placeLabel")
    m.timeLabel   = m.top.findNode("timeLabel")
    m.accentBar   = m.top.findNode("accentBar")

    m.qrOverlay  = m.top.findNode("qrOverlay")
    m.qrPoster   = m.top.findNode("qrPoster")
    m.qrCategory = m.top.findNode("qrCategory")
    m.qrTitle    = m.top.findNode("qrTitle")
    m.qrPlace    = m.top.findNode("qrPlace")
    m.qrTime     = m.top.findNode("qrTime")

    m.pulseAnim = m.top.findNode("pulseAnim")
    m.fadeOut   = m.top.findNode("fadeOut")
    m.fadeIn    = m.top.findNode("fadeIn")
    m.qrFadeIn  = m.top.findNode("qrFadeIn")
    m.qrFadeOut = m.top.findNode("qrFadeOut")

    m.markerTick   = m.top.findNode("markerTick")
    m.cycleTimer   = m.top.findNode("cycleTimer")
    m.refreshTimer = m.top.findNode("refreshTimer")

    ' State.
    m.events = []
    m.markerNodes = []
    m.lastPos = invalid
    m.index = -1
    m.overlayOpen = false

    ' Start the looping globe video.
    content = CreateObject("roSGNode", "ContentNode")
    content.url = "pkg:/video/globe_spin.mp4"
    content.streamFormat = "mp4"
    m.globeVideo.content = content
    m.globeVideo.loop = true
    m.globeVideo.enableUI = false
    m.globeVideo.notificationInterval = 0.25
    m.globeVideo.observeField("position", "onVideoPosition")
    m.globeVideo.control = "play"

    ' Observers / timers.
    m.fadeOut.observeField("state", "onFadeOutDone")
    m.markerTick.observeField("fire", "onMarkerTick")
    m.cycleTimer.observeField("fire", "onCycle")
    m.refreshTimer.observeField("fire", "onRefresh")

    m.markerTick.control = "start"
    m.cycleTimer.control = "start"
    m.refreshTimer.control = "start"
    m.top.setFocus(true)

    startFetch()
end sub

' ------------------------------------------------------------
' Rotation phase from the video clock
' ------------------------------------------------------------
sub onVideoPosition()
    m.lastPos = m.globeVideo.position
end sub

sub onMarkerTick()
    if m.lastPos = invalid then return
    revs = m.lastPos / m.secPerRev
    frac = revs - Int(revs)
    m.curLon0 = - frac * 360.0
    reprojectMarkers()
end sub

' Forward orthographic projection (matches the rendered video).
function project(lat as float, lng as float) as object
    latr = lat * m.D2R
    lon0 = m.curLon0 * m.D2R
    lat0 = m.gLat0 * m.D2R
    dl   = (lng * m.D2R) - lon0

    cosc = sin(lat0) * sin(latr) + cos(lat0) * cos(latr) * cos(dl)
    x = cos(latr) * sin(dl)
    y = cos(lat0) * sin(latr) - sin(lat0) * cos(latr) * cos(dl)

    return {
        x: m.gCX + x * m.gR,
        y: m.gCY - y * m.gR,
        front: (cosc >= 0.0)
    }
end function

' ------------------------------------------------------------
' Markers
' ------------------------------------------------------------
sub buildMarkers()
    existing = m.markersGroup.getChildren(-1, 0)
    if existing <> invalid and existing.count() > 0
        m.markersGroup.removeChildren(existing)
    end if
    m.markerNodes = []

    cap = m.events.count()
    if cap > 80 then cap = 80
    for i = 0 to cap - 1
        e = m.events[i]
        dot = m.markersGroup.createChild("Poster")
        dot.uri = "pkg:/images/dot.png"
        dot.width = 38 : dot.height = 38
        dot.blendColor = categoryColor(e.category)
        m.markerNodes.push(dot)
    end for
    reprojectMarkers()
end sub

sub reprojectMarkers()
    if m.markerNodes = invalid then return
    for i = 0 to m.markerNodes.count() - 1
        e = m.events[i]
        p = project(asFloat(e.lat), asFloat(e.lng))
        dot = m.markerNodes[i]
        if p.front
            dot.visible = true
            dot.translation = [p.x - 19, p.y - 19]
        else
            dot.visible = false
        end if
    end for

    if m.index >= 0 and m.index < m.events.count()
        e = m.events[m.index]
        p = project(asFloat(e.lat), asFloat(e.lng))
        m.highlightGroup.translation = [p.x, p.y]
        m.highlightHalo.visible = p.front
    end if
end sub

' ------------------------------------------------------------
' Data fetch
' ------------------------------------------------------------
sub startFetch()
    m.fetchTask = CreateObject("roSGNode", "NewsFetchTask")
    m.fetchTask.endpoint = "https://global-pulse-two.vercel.app/api/events"
    m.fetchTask.observeField("status", "onFetchDone")
    m.fetchTask.control = "RUN"
end sub

sub onRefresh()
    if m.fetchTask <> invalid
        m.fetchTask.control = "RUN"
    else
        startFetch()
    end if
end sub

sub onFetchDone()
    evts = m.fetchTask.events
    if evts = invalid or evts.count() = 0 then return

    m.events = evts
    m.liveTxt.text = "LIVE"
    m.evCount.text = m.events.count().ToStr() + " EVENTS"
    buildMarkers()

    if m.index < 0
        m.index = -1
        onCycle()
    end if
end sub

' ------------------------------------------------------------
' Event cycling + headline card
' ------------------------------------------------------------
sub onCycle()
    if m.overlayOpen then return
    if m.events = invalid or m.events.count() = 0 then return

    m.index = (m.index + 1) mod m.events.count()
    m.fadeOut.control = "start"   ' fade card out -> swap -> fade in
    if m.pulseAnim.state <> "running" then m.pulseAnim.control = "start"
end sub

sub onFadeOutDone()
    if m.fadeOut.state = "stopped"
        applyCurrentEvent()
        m.fadeIn.control = "start"
    end if
end sub

sub applyCurrentEvent()
    if m.index < 0 or m.index >= m.events.count() then return
    e = m.events[m.index]
    col = categoryColor(e.category)

    tag = ""
    if e.category <> invalid then tag = UCase(e.category)
    m.categoryTag.text = tag
    m.categoryTag.color = col
    m.accentBar.color = col
    m.highlightHalo.blendColor = col

    title = ""
    if e.title <> invalid then title = e.title
    if e.type <> invalid and LCase(e.type) = "quake" and e.mag <> invalid
        title = "M" + formatMag(e.mag) + " earthquake near " + nz(e.place, "")
    end if
    m.titleLabel.text = title
    m.placeLabel.text = nz(e.place, "")
    m.timeLabel.text = relativeTime(e.time)
end sub

' ------------------------------------------------------------
' QR overlay
' ------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "OK"
        if not m.overlayOpen then
            showQR()
            return true
        end if
    else if key = "back" or key = "up"
        if m.overlayOpen then
            hideQR()
            return true
        end if
    end if
    return false
end function

sub showQR()
    if m.index < 0 or m.index >= m.events.count() then return
    e = m.events[m.index]
    m.overlayOpen = true

    m.qrCategory.text = UCase(nz(e.category, "News"))
    m.qrCategory.color = categoryColor(e.category)
    m.qrTitle.text = nz(m.titleLabel.text, nz(e.title, ""))
    m.qrPlace.text = nz(e.place, "")
    m.qrTime.text = relativeTime(e.time)

    url = nz(e.url, "")
    if url <> ""
        m.qrPoster.uri = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=8&data=" + encodeURIComponent(url)
    else
        m.qrPoster.uri = ""
    end if

    m.qrOverlay.visible = true
    m.qrFadeIn.control = "start"
end sub

sub hideQR()
    m.overlayOpen = false
    m.qrFadeOut.observeField("state", "onQrFadeOutDone")
    m.qrFadeOut.control = "start"
end sub

sub onQrFadeOutDone()
    if m.qrFadeOut.state = "stopped"
        m.qrOverlay.visible = false
        m.qrFadeOut.unobserveField("state")
    end if
end sub

' ------------------------------------------------------------
' Helpers
' ------------------------------------------------------------
function asFloat(v as dynamic) as float
    if v = invalid then return 0.0
    return v
end function

function nz(v as dynamic, fallback as string) as string
    if v = invalid then return fallback
    if type(v) = "roString" or type(v) = "String" then return v
    return fallback
end function

function formatMag(mg as dynamic) as string
    if mg = invalid then return "?"
    n = Int(mg * 10.0 + 0.5)
    whole = Int(n / 10)
    frac = n - whole * 10
    return whole.ToStr() + "." + frac.ToStr()
end function

function relativeTime(ms as dynamic) as string
    if ms = invalid then return ""
    now = CreateObject("roDateTime").AsSeconds()
    secs = now - (ms / 1000.0)
    if secs < 0 then secs = 0
    if secs < 60 then return "just now"
    mins = Int(secs / 60.0)
    if mins < 60 then return mins.ToStr() + "m ago"
    hrs = Int(mins / 60)
    if hrs < 24 then return hrs.ToStr() + "h ago"
    days = Int(hrs / 24)
    return days.ToStr() + "d ago"
end function

function encodeURIComponent(s as string) as string
    safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    out = ""
    for i = 0 to Len(s) - 1
        ch = Mid(s, i + 1, 1)
        if Instr(1, safe, ch) > 0
            out = out + ch
        else
            out = out + "%" + toHex2(Asc(ch))
        end if
    end for
    return out
end function

function toHex2(code as integer) as string
    digits = "0123456789ABCDEF"
    hi = Int(code / 16)
    lo = code - hi * 16
    return Mid(digits, hi + 1, 1) + Mid(digits, lo + 1, 1)
end function
