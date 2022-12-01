# plot image in qrcode

function reshapewidth(img::AbstractMatrix, width::Int)
    imgx, imgy = size(img)
    rate = width / max(imgx, imgy)
    imgx, imgy = floor(Int, imgx * rate), floor(Int, imgy * rate)
    imresize(img, (imgx, imgy))
end

@testset "simulate image" begin
    # code inside code
    code = QRCode("Hello world -- Outer", version=13, eclevel=Medium(), width=4)
    mat = qrcode(code)
    submat = qrcode("Hello world! -- inner", version=2, width=3)
    leftop = 17 - 3, 17 - 3
    newmat = imageinqrcode(code, submat; leftop=leftop)
    newmat |> exportbitmat("testimages/code-inside-code")
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
    # test decoding
    stdmat = getqrmatrix("testimages/cam_fullinside.png")
    @test_throws InfoError qrdecompose(stdmat)
    
    # full screen
    bitimg = .!(Bool.(round.(reshapewidth(img, qrlen))))
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=false)
    exportbitmat(mat, "testimages/cam_fullscreen.png")
    @test true
    # test decoding
    stdmat = getqrmatrix("testimages/cam_fullscreen.png")
    @test mat == addborder(stdmat, code.border)    

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
    # test decoding
    stdmat = getqrmatrix("testimages/cam_fullinside2.png")
    @test mat == addborder(stdmat, code.border)

    # full screen
    img = .!(Bool.(round.(reshapewidth(img, qrlen))))
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=false)
    exportbitmat(mat, "testimages/cam_fullscreen2.png")
    @test true
    # test decoding
    stdmat = getqrmatrix("testimages/cam_fullscreen2.png")
    @test mat == addborder(stdmat, code.border)

    # test getecinfo
    _, nb1, _, nb2 = getecinfo(code)
    npureblock, nfreeblock, nfreebyte = getfreeinfo(code)
    @test nb1 + nb2 == npureblock + nfreeblock + 1
end

@testset "simulate image -- score over masks" begin
    # code with a lot of free bits
    img = testimage("cam")
    code = QRCode("HELLO WORLD", eclevel=Medium(), version=16, width=4)
    qrlen = qrwidth(code) - 2 * code.border # length of QR matrix
    bitimg = .!(Bool.(round.(reshapewidth(img, qrlen))))
    mats = Vector{BitMatrix}(undef, 8)
    for i in 1:8
        code.mask = i - 1
        mats[i] = imageinqrcode(code, bitimg, rate=1)
    end
    getimagescore.(mats, Ref(bitimg)) |> sort
    @test true

    # code with little free bits
    code = QRCode("Hello world!"^55)
    qrlen = qrwidth(code) - 2 * code.border # length of QR matrix
    bitimg = .!(Bool.(round.(reshapewidth(img, qrlen>>1))))
    mats = Vector{BitMatrix}(undef, 8)
    for i in 1:8
        code.mask = i - 1
        mats[i] = imageinqrcode(code, bitimg, rate=1)
    end
    getimagescore.(mats, Ref(bitimg)) |> sort
    @test true
end

@testset "simulate image -- test by QRDecoders" begin
    code = QRCode("Hello world", version=13, eclevel=Medium(), width=0, mode=UTF8())
    img = rand(Bool, 40, 40)
    # no error
    mat = imageinqrcode(code, img, rate=0)
    @test_throws DecodeError qrdecode(mat) # modified padbits
    @test qrdecode(mat, checkrem=false, noerror=true) == code
    
    # contains error
    mat = imageinqrcode(code, img, rate=1, singlemask=false)
    @test_throws DecodeError qrdecode(mat) # modified padbits
    @test_throws DecodeError qrdecode(mat, checkrem=false, noerror=true) # cotains error
    @test qrdecode(mat, checkrem=false, noerror=false) == code

    # code with little free bits
    code = QRCode("hello world!"^55, width=0, mode=UTF8())
    @test qrdecode(qrcode(code)) == code
    img = rand(Bool, 100, 100)
    bitimg = .!(Bool.(round.(reshapewidth(img, fitimgwidth(code)))))
    ## singlemask
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=true)
    @test_throws DecodeError qrdecode(mat)
    @test qrdecode(mat, checkrem=false) == code
    ## all masks
    mat = imageinqrcode(code, bitimg, rate=1, singlemask=false)
    @test_throws DecodeError qrdecode(mat)
    @test qrdecode(mat, checkrem=false).message == code.message
end