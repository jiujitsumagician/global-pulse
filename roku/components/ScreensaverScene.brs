' ============================================================
' ScreensaverScene.brs
' Builds the markers, cycles through events, animates the
' headline card, and shows a QR overlay on OK/Select.
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
    return "0x9fb4c8ff"
end function

sub init()
    ' Dark space background.
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x05080FFF"

    ' --- Equirectangular base map (NASA Blue Marble, public domain,
    '     bundled in the package so it always loads — no runtime
    '     network/hotlink dependency. 2048x1024, same texture the web
    '     globe uses (three-globe earth-blue-marble). ---
    m.mapPoster = m.top.findNode("mapPoster")
    m.mapPoster.uri = "pkg:/images/world.jpg"

    ' Geometry used for lat/lng -> pixel mapping. Must match the
    ' mapPoster translation/size in the XML.
    m.mapW = 1960 : m.mapH = 980 : m.mapLeft = -20 : m.mapTop = 50

    ' Node handles.
    m.markersGroup   = m.top.findNode("markersGroup")
    m.highlightGroup = m.top.findNode("highlightGroup")
    m.highlightHalo  = m.top.findNode("highlightHalo")
    m.cardGroup      = m.top.findNode("cardGroup")
    m.categoryTag    = m.top.findNode("categoryTag")
    m.titleLabel     = m.top.findNode("titleLabel")
    m.placeLabel     = m.top.findNode("placeLabel")
    m.timeLabel      = m.top.findNode("timeLabel")

    m.qrOverlay  = m.top.findNode("qrOverlay")
    m.qrPoster   = m.top.findNode("qrPoster")
    m.qrCategory = m.top.findNode("qrCategory")
    m.qrTitle    = m.top.findNode("qrTitle")
    m.qrPlace    = m.top.findNode("qrPlace")
    m.qrTime     = m.top.findNode("qrTime")

    m.fadeOut = m.top.findNode("fadeOut")
    m.fadeIn  = m.top.findNode("fadeIn")
    m.pulseAnim = m.top.findNode("pulseAnim")
    m.driftAnim = m.top.findNode("driftAnim")
    m.qrFadeIn  = m.top.findNode("qrFadeIn")
    m.qrFadeOut = m.top.findNode("qrFadeOut")

    m.cycleTimer   = m.top.findNode("cycleTimer")
    m.refreshTimer = m.top.findNode("refreshTimer")

    ' State.
    m.events = []
    m.positions = []
    m.index = -1
    m.overlayOpen = false

    ' Observers.
    m.fadeOut.observeField("state", "onFadeOutDone")
    m.cycleTimer.observeField("fire", "onCycle")
    m.refreshTimer.observeField("fire", "onRefresh")

    ' Start ambient motion + timers.
    m.driftAnim.control = "start"
    m.cycleTimer.control = "start"
    m.refreshTimer.control = "start"

    ' Allow OK/Back key handling (works when launched as a channel;
    ' see README for the screensaver-mode caveat).
    m.top.setFocus(true)

    startFetch()
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
    ' Re-run the fetch task every 5 minutes.
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
    buildMarkers()

    ' Show the first event immediately on the very first load.
    if m.index < 0
        m.index = -1
        onCycle()
    end if
end sub

' ------------------------------------------------------------
' Markers
' ------------------------------------------------------------
function latLngToXY(lat as dynamic, lng as dynamic) as object
    la = 0.0 : ln = 0.0
    if lat <> invalid then la = lat
    if lng <> invalid then ln = lng
    x = (ln + 180.0) / 360.0 * m.mapW + m.mapLeft
    y = (90.0 - la) / 180.0 * m.mapH + m.mapTop
    return [x, y]
end function

sub buildMarkers()
    ' Clear existing markers.
    existing = m.markersGroup.getChildren(-1, 0)
    if existing <> invalid and existing.count() > 0
        m.markersGroup.removeChildren(existing)
    end if
    m.positions = []

    for each e in m.events
        xy = latLngToXY(e.lat, e.lng)
        m.positions.push(xy)
        col = categoryColor(e.category)

        marker = m.markersGroup.createChild("Group")
        marker.translation = xy

        ' Round glowing dot: a white radial-glow texture tinted to the
        ' category color via blendColor (Rectangles can only be square).
        dot = marker.createChild("Poster")
        dot.uri = "pkg:/images/dot.png"
        dot.width = 30 : dot.height = 30
        dot.translation = [-15, -15]
        dot.blendColor = col
    end for
end sub

' ------------------------------------------------------------
' Event cycling + headline card
' ------------------------------------------------------------
sub onCycle()
    ' Don't advance while the QR overlay is open.
    if m.overlayOpen then return
    if m.events = invalid or m.events.count() = 0 then return

    m.index = (m.index + 1) mod m.events.count()
    m.fadeOut.control = "start"   ' fade out -> swap content -> fade in
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
    m.top.findNode("accentBar").color = col

    title = ""
    if e.title <> invalid then title = e.title
    if e.type <> invalid and LCase(e.type) = "quake" and e.mag <> invalid
        title = "M" + formatMag(e.mag) + " earthquake near " + nz(e.place, "")
    end if
    m.titleLabel.text = title

    m.placeLabel.text = nz(e.place, "")
    m.timeLabel.text = relativeTime(e.time)

    ' Move + pulse the highlight halo over this event.
    if m.index < m.positions.count()
        m.highlightGroup.translation = m.positions[m.index]
        m.highlightHalo.blendColor = col
        if m.pulseAnim.state <> "running" then m.pulseAnim.control = "start"
    end if
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
function nz(v as dynamic, fallback as string) as string
    if v = invalid then return fallback
    if type(v) = "roString" or type(v) = "String" then return v
    return fallback
end function

function formatMag(mg as dynamic) as string
    if mg = invalid then return "?"
    f = mg
    ' One decimal place.
    n = Int(f * 10.0 + 0.5)
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

' Percent-encode a string for use in a URL query value.
function encodeURIComponent(s as string) as string
    safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    out = ""
    for i = 0 to Len(s) - 1
        ch = Mid(s, i + 1, 1)
        if Instr(1, safe, ch) > 0
            out = out + ch
        else
            code = Asc(ch)
            out = out + "%" + toHex2(code)
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
