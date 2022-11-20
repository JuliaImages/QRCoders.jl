# plot image in qrcode
"""
    recommendshape(code::QRCode, img::AbstractMatrix)
"""
function recommentshape(code::QRCode, img::AbstractMatrix)
    qrlen = qrwidth(code) - 2 * code.border
    imgx, imgy = size(img)
    recx = qrlen - 2 * 9 # skip the finder patterns and format information
    recy = qrlen
    rate = min(recx / imgx, recy / imgy)
    imgx, imgy = floor(Int, imgx * rate), floor(Int, imgy * rate)
    imresize(img, (imgx, imgy))
end


@testset "simulate image" begin
    # image in qrcode
    code = QRCode("HELLO WORLD", eclevel=High(), version=10, width=4)
    img = testimage("cam")
    img = .!(Bool.(round.(recommentshape(code, img))))
    mat = imageinqrcode(code, img, rate=1, singlemask=false)
    mat |> unicodeplotbychar |> println
    exportbitmat(mat, "testimages/cam.png")
    @test true
end