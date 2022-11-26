# plot image in qrcode

function reshapewidth(img::AbstractMatrix, width::Int)
    imgx, imgy = size(img)
    rate = width / max(imgx, imgy)
    imgx, imgy = floor(Int, imgx * rate), floor(Int, imgy * rate)
    imresize(img, (imgx, imgy))
end

@testset "simulate image" begin
    code = QRCode("HELLO WORLD", eclevel=Medium(), version=16, width=4)
    # image in qrcode
    img = testimage("cam")
    qrlen = qrwidth(code) - 2 * code.border # length of QR matrix
    # full inside
    bitimg = .!(Bool.(round.(reshapewidth(img, fitimgwidth(code)))))
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=false, fillaligment=true)
    @test getimagescore(mat, bitimg) ≤ 100
    exportbitmat(mat, "testimages/cam_fullinside.png")
    @test true
    
    # full screen
    bitimg = .!(Bool.(round.(reshapewidth(img, qrlen))))
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=false)
    exportbitmat(mat, "testimages/cam_fullscreen.png")
    @test true

    # QR code with too much information
    code = QRCode("hello world!"^55, width=4)
    img = testimage("cam")
    qrlen = qrwidth(code) - 2 * code.border # length of QR matrix
    insidelen = qrlen - 16 # skip finder patterns
    # full inside
    bitimg = .!(Bool.(round.(reshapewidth(img, insidelen))))
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=false)
    exportbitmat(mat, "testimages/cam_fullinside2.png")
    @test true
    # full screen
    img = .!(Bool.(round.(reshapewidth(img, qrlen))))
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=false)
    exportbitmat(mat, "testimages/cam_fullscreen2.png")
    @test true

    # test getecinfo
    _, nb1, _, nb2 = getecinfo(code)
    npureblock, nfreeblock, nfreebyte = getfreeinfo(code)
    @test nb1 + nb2 == npureblock + nfreeblock + 1

    # badapple
    # oriimg = load("testimages/badapple.png")
    # code = QRCode("HELLO WORLD", eclevel=High(), version=13, width=4)
    # qrlen = qrwidth(code) - 2 * code.border # length of QR matrix
    # insidelen = qrlen - 16 # skip finder patterns
    # img = .!(Bool.(round.(Gray.(reshapewidth(oriimg, insidelen)))))
    # mat = imageinqrcode(code, img, rate=1, singlemask=true)
    # mat |> exportbitmat("testimages/badapple_fullinside")
    # img = .!(Bool.(round.(Gray.(reshapewidth(oriimg, qrlen)))))
    # mat = imageinqrcode(code, img, rate=.9, singlemask=true)
    # mat |> exportbitmat("testimages/badapple_fullscreen")
end