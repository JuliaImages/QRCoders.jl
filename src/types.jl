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

function Base.show(io::IO, ::MIME"image/svg+xml", s::QRCode)
    qrm = qrcode(s.s, s.eclevel)
    write(io, qrsvg(s))
end

function qr(txt::String)
    qrm = plainqr(txt)
    scale = Int(round(200/size(qrm,1)))
    return Gray.(repeat(.!(plainqr(txt)),inner=(scale,scale)))
end

function plainqr(txt::String)
    return qrcode(txt)
end

function qrsvg(qrc::QRCode)
    svg = IOBuffer()
    qrm = qrcode(qrc.s, qrc.eclevel)
    I, J = size(qrm)
    composition = compose(context(), fill("black"),
    ((context((i-1)/I,(j-1)/J,1/I + 1e-3,1/J + 1e-3), rectangle()) 
        for i=1:size(qrm,1),j=1:size(qrm,2) if qrm[i,j]==1 )...
    )
    composition |> SVG(svg, 5cm, 5cm)
    return take!(svg)
end