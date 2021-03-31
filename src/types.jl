struct QRCode{T} # Avoid name clash with qr factorization and QRCode
    s::String
    eclevel::T
end
QRCode(s) = QRCode(s, Medium())

function Base.show(io::IO, ::MIME"text/plain", s::QRCode)
    qrm = qrcode(s.s, s.eclevel)
    print(io, UnicodePlots.heatmap(qrm;
                        padding=0,margin=0,border=:none,
                        width=size(qrm,2),colormap=[(1,1,1),(0,0,0)],labels=false))
end

function Base.show(io::IO, ::MIME"image/png", s::QRCode)
    qrm = qrcode(s.s, s.eclevel)
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
