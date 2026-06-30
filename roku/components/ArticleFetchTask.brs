' ============================================================
' ArticleFetchTask.brs
' GET /api/article?url=... -> { paragraphs[], images[], site }.
' Publishes a joined blurb + first image back to the scene.
' ============================================================

sub init()
    m.top.functionName = "run"
end sub

sub run()
    blurb = ""
    image = ""

    u = m.top.url
    if u <> invalid and u <> ""
        api = "https://global-pulse-two.vercel.app/api/article?url=" + encodeURIComponent(u)
        body = httpGetString(api)
        if body <> invalid and body <> ""
            j = ParseJson(body)
            if j <> invalid
                if j.paragraphs <> invalid
                    n = 0
                    for each p in j.paragraphs
                        if p <> invalid and Len(p) > 0
                            if blurb <> "" then blurb = blurb + Chr(10) + Chr(10)
                            blurb = blurb + p
                            n = n + 1
                        end if
                        if n >= 3 then exit for
                    end for
                end if
                if j.images <> invalid and j.images.count() > 0
                    image = j.images[0]
                end if
            end if
        end if
    end if

    m.top.blurb = blurb
    m.top.image = image
    m.top.done = m.top.done + 1
end sub

function httpGetString(url as string) as dynamic
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetRequest("GET")
    ut.AddHeader("Accept", "application/json")
    if Left(LCase(url), 5) = "https"
        ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
        ut.InitClientCertificates()
    end if
    port = CreateObject("roMessagePort")
    ut.SetMessagePort(port)
    if ut.AsyncGetToString()
        msg = wait(9000, port)
        if type(msg) = "roUrlEvent"
            if msg.GetResponseCode() = 200 then return msg.GetString()
        else if msg = invalid
            ut.AsyncCancel()
        end if
    end if
    return invalid
end function

function encodeURIComponent(s as string) as string
    safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    out = ""
    for i = 0 to Len(s) - 1
        ch = Mid(s, i + 1, 1)
        if Instr(1, safe, ch) > 0
            out = out + ch
        else
            code = Asc(ch)
            hi = Int(code / 16) : lo = code - hi * 16
            digits = "0123456789ABCDEF"
            out = out + "%" + Mid(digits, hi + 1, 1) + Mid(digits, lo + 1, 1)
        end if
    end for
    return out
end function
