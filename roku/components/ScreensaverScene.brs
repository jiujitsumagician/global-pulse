' ============================================================
' ScreensaverScene.brs  (3D-globe edition)
' Rotates a pre-rendered orthographic Earth, projects live event
' markers onto the sphere, "flies" to each event by spinning the
' globe so the event sits front-and-centre, then shows a headline
' card. OK opens a QR overlay for the current event.
'
' The projection here MUST match tools/render_globe.py:
'   gN frames, frame i centred on longitude  -i*(360/gN)
'   camera tilt gLat0, globe radius gR at screen (gCX,gCY)
' ============================================================

' ---- Category -> marker/accent color (0xRRGGBBAA) ----------
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
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x04060CFF"

    ' --- globe geometry: keep in sync with tools/render_globe.py ---
    ' 1080-space: globe frames are 1280x720, stretched 1.5x to fill the
    ' 1920x1080 design surface (both 16:9, so no distortion).
    m.gN    = 72
    m.gR    = 498.0
    m.gCX   = 960.0
    m.gCY   = 489.0
    m.gLat0 = 16.0
    m.PI    = 3.1415926535
    m.D2R   = m.PI / 180.0

    ' Pre-rendered rotation frames.
    m.frames = []
    for i = 0 to m.gN - 1
        m.frames.push("pkg:/images/globe/frame_" + pad3(i) + ".jpg")
    end for

    ' Node handles.
    m.globeStage   = m.top.findNode("globeStage")
    m.globePoster  = m.top.findNode("globePoster")
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
    m.zoomIn    = m.top.findNode("zoomIn")
    m.zoomOut   = m.top.findNode("zoomOut")
    m.fadeOut   = m.top.findNode("fadeOut")
    m.fadeIn    = m.top.findNode("fadeIn")
    m.qrFadeIn  = m.top.findNode("qrFadeIn")
    m.qrFadeOut = m.top.findNode("qrFadeOut")

    m.spinTimer    = m.top.findNode("spinTimer")
    m.flyTimer     = m.top.findNode("flyTimer")
    m.cycleTimer   = m.top.findNode("cycleTimer")
    m.refreshTimer = m.top.findNode("refreshTimer")

    ' State.
    m.events = []
    m.markerNodes = []
    m.frame = 0
    m.flyTarget = 0
    m.flying = false
    m.zoomed = false
    m.index = -1
    m.overlayOpen = false

    ' Observers.
    m.fadeOut.observeField("state", "onFadeOutDone")
    m.spinTimer.observeField("fire", "onSpin")
    m.flyTimer.observeField("fire", "onFlyStep")
    m.cycleTimer.observeField("fire", "onCycle")
    m.refreshTimer.observeField("fire", "onRefresh")

    showFrame()
    m.spinTimer.control = "start"
    m.cycleTimer.control = "start"
    m.refreshTimer.control = "start"
    m.top.setFocus(true)

    startFetch()
end sub

' ------------------------------------------------------------
' Globe rotation
' ------------------------------------------------------------
sub showFrame()
    m.globePoster.uri = m.frames[m.frame]
    reprojectMarkers()
end sub

sub onSpin()
    if m.flying or m.overlayOpen then return
    m.frame = (m.frame + 1) mod m.gN          ' idle: drift eastward
    showFrame()
end sub

' Spin step-by-step toward the target frame during a fly-to.
sub onFlyStep()
    if m.frame = m.flyTarget
        m.flyTimer.control = "stop"
        m.flying = false
        landOnEvent()
        return
    end if
    ' shortest direction around the 360 ring
    diff = ((m.flyTarget - m.frame + m.gN) mod m.gN)
    if diff <= m.gN / 2
        m.frame = (m.frame + 1) mod m.gN
    else
        m.frame = (m.frame - 1 + m.gN) mod m.gN
    end if
    showFrame()
end sub

' ------------------------------------------------------------
' Orthographic projection (forward) — matches render_globe.py.
' Returns roAssociativeArray { x, y, front }.
' ------------------------------------------------------------
function project(lat as float, lng as float) as object
    latr = lat * m.D2R
    lon0 = (- m.frame * (360.0 / m.gN)) * m.D2R
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

    ' keep the active highlight glued to its event as the globe turns
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
' Event cycling + fly-to
' ------------------------------------------------------------
sub onCycle()
    if m.overlayOpen then return
    if m.events = invalid or m.events.count() = 0 then return

    m.index = (m.index + 1) mod m.events.count()
    e = m.events[m.index]

    ' frame whose centre longitude best matches this event's longitude
    stepDeg = 360.0 / m.gN
    f = Int((- asFloat(e.lng) / stepDeg) + 0.5)
    f = ((f mod m.gN) + m.gN) mod m.gN
    m.flyTarget = f

    m.flying = true
    if not m.zoomed
        m.zoomIn.control = "start"
        m.zoomed = true
    end if
    m.flyTimer.control = "start"
end sub

' Called when the fly-to spin reaches the event.
sub landOnEvent()
    m.fadeOut.control = "start"   ' fade card out -> swap -> fade in
    if m.pulseAnim.state <> "running" then m.pulseAnim.control = "start"
    reprojectMarkers()
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
function pad3(i as integer) as string
    s = i.ToStr()
    if Len(s) = 1 then return "00" + s
    if Len(s) = 2 then return "0" + s
    return s
end function

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
