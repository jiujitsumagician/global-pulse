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
    m.secPerRev = 31.3       ' seconds per full revolution in the video loop (720f @ 23fps)
    m.curLon0 = 0.0

    ' Nodes.
    m.globeCamera = m.top.findNode("globeCamera")
    m.globeVideo  = m.top.findNode("globeVideo")
    m.globeStill  = m.top.findNode("globeStill")
    m.markersGroup = m.top.findNode("markersGroup")

    ' still frames matching the video, one per 5 deg (lon0 = -j*5)
    m.stillUris = []
    for j = 0 to 71
        m.stillUris.push("pkg:/images/globe_still/still_" + pad3(j) + ".jpg")
    end for
    m.highlightGroup = m.top.findNode("highlightGroup")
    m.highlightHalo  = m.top.findNode("highlightHalo")

    m.liveTxt  = m.top.findNode("liveTxt")
    m.evCount  = m.top.findNode("evCount")
    m.timeText = m.top.findNode("timeText")
    m.dateText = m.top.findNode("dateText")

    m.detailPanel = m.top.findNode("detailPanel")
    m.panelBg     = m.top.findNode("panelBg")
    m.categoryTag = m.top.findNode("categoryTag")
    m.titleLabel  = m.top.findNode("titleLabel")
    m.placeLabel  = m.top.findNode("placeLabel")
    m.coordLabel  = m.top.findNode("coordLabel")
    m.sourceLabel = m.top.findNode("sourceLabel")
    m.blurbLabel  = m.top.findNode("blurbLabel")
    m.timeLabel   = m.top.findNode("timeLabel")
    m.accentBar   = m.top.findNode("accentBar")
    m.heroImg     = m.top.findNode("heroImg")
    m.heroPlaceholder = m.top.findNode("heroPlaceholder")
    m.heroWatermark   = m.top.findNode("heroWatermark")

    m.pulseAnim = m.top.findNode("pulseAnim")
    m.fadeOut   = m.top.findNode("fadeOut")
    m.fadeIn    = m.top.findNode("fadeIn")

    m.markerTick   = m.top.findNode("markerTick")
    m.cycleTimer   = m.top.findNode("cycleTimer")
    m.refreshTimer = m.top.findNode("refreshTimer")
    m.clockTimer   = m.top.findNode("clockTimer")

    ' State.
    m.events = []
    m.markerNodes = []
    m.started = false
    m.basePos = 0.0
    m.clock = CreateObject("roTimespan")
    m.clock.Mark()
    m.index = -1

    ' rotate-to-event-then-pause tour
    m.spinning = false
    m.tourOrder = []
    m.tourPos = -1
    m.spinStartL = 0.0
    m.spinDelta = 0.0
    m.spinTargetLon0 = 0.0

    ' Start the looping globe video.
    content = CreateObject("roSGNode", "ContentNode")
    content.url = "pkg:/video/globe_spin.mp4"
    content.streamFormat = "mp4"
    m.globeVideo.content = content
    m.globeVideo.loop = true
    m.globeVideo.enableUI = false
    m.globeVideo.notificationInterval = 0.1
    m.globeVideo.observeField("position", "onVideoPosition")
    m.globeVideo.control = "play"

    ' Observers / timers.
    m.markerTick.observeField("fire", "onMarkerTick")
    m.cycleTimer.observeField("fire", "onCycle")
    m.refreshTimer.observeField("fire", "onRefresh")

    m.markerTick.control = "start"
    m.refreshTimer.control = "start"   ' cycleTimer (dwell) starts on first arrival
    m.clockTimer.observeField("fire", "onClockTick")
    m.clockTimer.control = "start"
    updateClock()

    startFetch()
end sub

' ------------------------------------------------------------
' Local clock (device time zone) — bottom-right
' ------------------------------------------------------------
sub onClockTick()
    updateClock()
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()

    hh = dt.GetHours()
    mm = dt.GetMinutes()
    ampm = "AM"
    if hh >= 12 then ampm = "PM"
    h12 = hh mod 12
    if h12 = 0 then h12 = 12
    mmStr = mm.ToStr()
    if mm < 10 then mmStr = "0" + mmStr
    m.timeText.text = h12.ToStr() + ":" + mmStr + " " + ampm

    months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
    mo = dt.GetMonth()
    if mo < 1 or mo > 12 then mo = 1
    m.dateText.text = dt.GetWeekday() + ", " + months[mo - 1] + " " + dt.GetDayOfMonth().ToStr()
end sub

' ------------------------------------------------------------
' Rotation phase from the video clock
' ------------------------------------------------------------
' Resync the smooth local clock to the (sparsely reported) video position so
' markers stay aligned to the actual rotation without drifting.
sub onVideoPosition()
    m.basePos = m.globeVideo.position
    m.clock.Mark()
    m.started = true
end sub

' Driven at 30 Hz off a local clock (not the 10 Hz position polls) so marker
' motion matches the smoothness of the hardware-decoded globe. While spinning,
' the globe (video) is playing and markers advance; once we reach the featured
' event the video is PAUSED and markers freeze, so the globe stops on the event.
sub onMarkerTick()
    if not m.started then return
    if m.spinning
        ' reveal the live (rotating) video only once it's actually playing,
        ' so the resume from pause never shows through as black
        if m.globeStill.visible and m.globeVideo.state = "playing"
            m.globeStill.visible = false
        end if
        t = m.basePos + (m.clock.TotalMilliseconds() / 1000.0)
        frac = (t / m.secPerRev) - Int(t / m.secPerRev)
        curL = frac * 360.0
        m.curLon0 = - curL
        reprojectMarkers()
        if normalize360(curL - m.spinStartL) >= m.spinDelta then onArrive()
    else
        reprojectMarkers()        ' holding: still shown, markers frozen on the event
    end if
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

    ' tour order = events sorted by their centred-longitude key so the globe
    ' sweeps in short hops, pausing at each event location in turn
    ord = []
    for i = 0 to m.events.count() - 1
        ord.push({ i: i, key: normalize360(- asFloat(m.events[i].lng)) })
    end for
    ord.SortBy("key")
    m.tourOrder = []
    for each o in ord
        m.tourOrder.push(o.i)
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

    if m.tourPos < 0
        startSpinToNext()         ' begin the tour at the first event
    end if
end sub

' ------------------------------------------------------------
' Event tour: rotate to each event location, then pause on it
' ------------------------------------------------------------
sub onCycle()
    startSpinToNext()             ' dwell timer fired -> move to the next event
end sub

sub startSpinToNext()
    if m.events = invalid or m.events.count() = 0 then return
    if m.tourOrder.count() = 0 then return

    m.tourPos = (m.tourPos + 1) mod m.tourOrder.count()
    m.index = m.tourOrder[m.tourPos]
    e = m.events[m.index]

    m.fadeOut.control = "start"          ' hide the old card during the move
    m.highlightHalo.blendColor = categoryColor(e.category)

    targetL = normalize360(- asFloat(e.lng))
    curL = normalize360(- m.curLon0)
    m.spinStartL = curL
    m.spinDelta = normalize360(targetL - curL)
    m.spinTargetLon0 = - targetL

    if m.spinDelta < 2.0
        onArrive()                       ' already centred (same longitude)
    else
        ' resume the video; keep the still up until the video is actually
        ' playing again (onMarkerTick hides it) so there's no black flash
        m.spinning = true
        m.globeVideo.control = "resume"
        m.basePos = m.globeVideo.position
        m.clock.Mark()
    end if
end sub

sub onArrive()
    m.spinning = false
    e = m.events[m.index]

    ' snap to the nearest still frame and show it (the paused video is black on
    ' this device, so the still — on the graphics plane — is what's displayed)
    targetL = normalize360(- asFloat(e.lng))
    j = Int(targetL / 5.0 + 0.5)
    if j >= 72 then j = 0
    m.curLon0 = - (j * 5.0)
    m.globeStill.uri = m.stillUris[j]
    m.globeStill.visible = true
    m.globeVideo.control = "pause"       ' hidden behind the still; just stops it advancing

    reprojectMarkers()
    applyCurrentEvent()
    m.fadeIn.control = "start"
    if m.pulseAnim.state <> "running" then m.pulseAnim.control = "start"
    m.cycleTimer.control = "start"       ' begin the dwell hold
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

    ' reflow the lower block beneath the variable-length headline so long
    ' titles aren't clipped and short ones don't leave a huge gap
    tLines = computeLines(title, 30)
    baseY = 326 + tLines * 46 + 34
    m.placeLabel.translation  = [36, baseY]
    m.coordLabel.translation  = [36, baseY + 50]
    m.sourceLabel.translation = [36, baseY + 92]
    m.blurbLabel.translation  = [36, baseY + 146]

    ' size the panel + hint to hug the content (no dead space)
    hintY = baseY + 146 + 150 + 24
    m.hintLabel.translation = [36, hintY]
    panelH = hintY + 44
    m.panelBg.height = panelH
    m.accentBar.height = panelH

    m.placeLabel.text = "◉ " + nz(e.place, "")
    m.timeLabel.text = relativeTime(e.time)
    m.coordLabel.text = formatCoord(e.lat, e.lng)
    src = nz(e.source, "")
    if src <> "" then src = UCase(src)
    m.sourceLabel.text = src

    ' hero image — use the event's own image immediately if it has one;
    ' otherwise a category-tinted placeholder + watermark fills the space.
    m.heroWatermark.text = tag
    m.heroWatermark.color = Left(col, 8) + "55"
    m.heroPlaceholder.color = Left(col, 8) + "1f"
    img = nz(e.image, "")
    m.curImage = img
    m.heroImg.uri = img

    ' blurb — synthesized fallback now, upgraded by the fetched article text
    m.blurbLabel.text = fallbackBlurb(e)
    fetchArticle(e)
end sub

' ------------------------------------------------------------
' Article blurb + image (mirrors the PC detail panel)
' ------------------------------------------------------------
sub fetchArticle(e as object)
    u = nz(e.url, "")
    isNews = (e.type <> invalid and LCase(e.type) = "news")
    if not isNews or Left(LCase(u), 4) <> "http" then return
    if m.articleTask = invalid
        m.articleTask = CreateObject("roSGNode", "ArticleFetchTask")
        m.articleTask.observeField("done", "onArticleDone")
    end if
    m.articleTask.url = u
    m.articleTask.control = "RUN"
end sub

sub onArticleDone()
    if m.index < 0 or m.index >= m.events.count() then return
    e = m.events[m.index]
    if nz(e.url, "") <> m.articleTask.url then return    ' a newer event superseded this
    b = m.articleTask.blurb
    if b <> invalid and b <> "" then m.blurbLabel.text = b
    if m.curImage = invalid or m.curImage = ""
        im = m.articleTask.image
        if im <> invalid and im <> "" then m.heroImg.uri = im
    end if
end sub

function fallbackBlurb(e as object) as string
    t = ""
    if e.type <> invalid then t = LCase(e.type)
    place = nz(e.place, "the region")
    if t = "quake"
        return "A magnitude " + formatMag(e.mag) + " earthquake was recorded near " + place + ". Live seismic data from the USGS — press OK for the full event report."
    else if t = "space"
        return nz(e.title, "A rocket launch") + " — staged from " + place + ". Tracked via The Space Devs launch database. Press OK for mission details."
    else if t = "nature"
        return nz(e.title, "An active natural event") + " (" + place + "), tracked by NASA EONET. Press OK for the latest source reports."
    else if t = "weather"
        return "An active severe-weather alert for " + place + ", issued by the US National Weather Service."
    end if
    return "Reported via " + nz(e.source, "wire services") + " from " + place + ". Press OK to open the full article on your phone."
end function

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

' Rough line-count estimate for a wrapped Label (proportional font), used to
' reflow the panel. Slightly over-estimates so blocks don't collide.
function pad3(i as integer) as string
    s = i.ToStr()
    if Len(s) = 1 then return "00" + s
    if Len(s) = 2 then return "0" + s
    return s
end function

function normalize360(x as float) as float
    y = x - Int(x / 360.0) * 360.0
    if y < 0.0 then y = y + 360.0
    return y
end function

function computeLines(s as dynamic, cpl as integer) as integer
    if s = invalid or Len(s) = 0 then return 1
    n = Int((Len(s) - 1) / cpl) + 1
    if n < 1 then n = 1
    if n > 4 then n = 4
    return n
end function

function formatCoord(lat as dynamic, lng as dynamic) as string
    return fmtDeg(lat) + ", " + fmtDeg(lng)
end function

function fmtDeg(v as dynamic) as string
    if v = invalid then return "?"
    x = v
    neg = (x < 0)
    if neg then x = -x
    n = Int(x * 100.0 + 0.5)
    whole = Int(n / 100)
    frac = n - whole * 100
    fs = frac.ToStr()
    if Len(fs) = 1 then fs = "0" + fs
    s = whole.ToStr() + "." + fs + "°"
    if neg then s = "-" + s
    return s
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
