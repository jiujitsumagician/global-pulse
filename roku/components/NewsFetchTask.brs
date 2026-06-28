' ============================================================
' NewsFetchTask.brs
' Runs on its own thread. Fetches + parses the events feed,
' falling back to the bundled sample file on any failure.
' ============================================================

sub init()
    m.top.functionName = "fetchEvents"
end sub

sub fetchEvents()
    parsed = invalid
    src = "sample"

    url = m.top.endpoint
    if url = invalid or url = "" then url = "https://global-pulse-two.vercel.app/api/events"

    ' --- 1) Try the live endpoint -------------------------------------
    body = httpGetString(url)
    if body <> invalid and body <> ""
        candidate = ParseJson(body)
        if candidate <> invalid and candidate.events <> invalid and candidate.events.count() > 0
            parsed = candidate
            src = "live"
        end if
    end if

    ' --- 2) Fall back to the bundled sample file ---------------------
    if parsed = invalid
        localText = ReadAsciiFile("pkg:/events_sample.json")
        if localText <> invalid and localText <> ""
            candidate = ParseJson(localText)
            if candidate <> invalid and candidate.events <> invalid
                parsed = candidate
                src = "sample"
            end if
        end if
    end if

    ' --- 3) Publish results back to the render thread ---------------
    if parsed <> invalid and parsed.events <> invalid
        m.top.events = parsed.events
        m.top.source = src
        m.top.status = "ok"
    else
        m.top.events = []
        m.top.source = "none"
        m.top.status = "error"
    end if
end sub

' Synchronous-with-timeout GET. Returns the body string or invalid.
function httpGetString(url as string) as dynamic
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetRequest("GET")
    ut.AddHeader("Accept", "application/json")

    ' HTTPS requires the cert bundle + client certs on Roku.
    if Left(LCase(url), 5) = "https"
        ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
        ut.InitClientCertificates()
    end if

    port = CreateObject("roMessagePort")
    ut.SetMessagePort(port)

    if ut.AsyncGetToString()
        msg = wait(15000, port)   ' 15s timeout
        if type(msg) = "roUrlEvent"
            if msg.GetResponseCode() = 200
                return msg.GetString()
            end if
        else if msg = invalid
            ut.AsyncCancel()       ' timed out
        end if
    end if
    return invalid
end function
