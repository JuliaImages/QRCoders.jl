struct QRC # Avoid name clash with qr factorization and QRCode
    s::String
end

function Base.show(io::IO, ::MIME"text/plain", s::QRC)
    qrm = plainqr(s.s)
    print(io, UnicodePlots.heatmap(qrm;
                        padding=0,margin=0,border=:none,
                        width=size(qrm,2),colormap=[(1,1,1),(0,0,0)],labels=false))
end

function Base.show(io::IO, ::MIME"image/png", s::QRC)
    qrm = plainqr(s.s)
    scale = Int(round(200/size(qrm,1)))
    qrm = Gray.(repeat(.!qrm, inner=(scale,scale)))
    png = IOBuffer()
    save(Stream(format"PNG", png), qrm)
    write(io, take!(png))
end

function qr(txt::String)
    qrm = plainqr(txt)
    scale = Int(round(200/size(qrm,1)))
    return Gray.(repeat(.!(plainqr(txt)),inner=(scale,scale)))
end

function plainqr(txt::String)
    return qrcode(txt)
end
