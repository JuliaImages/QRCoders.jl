# test for struct type `QRCode`

@testset "struct type QRCode" begin
    # test for show methods
    code = QRCode("Hello world!")
    exportqrcode(code, imgpath * "qrcode-byqr-helloworld.png")
    println(code)
    @test true

    # initialize with specified mask and mode
    code = QRCode("Hello world!"; mask = 0, mode=Numeric())
    exportqrcode(code, imgpath * "qrcode-byqr-mask0.png")
    @test true

    ## initialize by direct method, it will raise error
    ## if specified mode/version is invalid!!
    code = QRCode(1, Numeric(), Medium(), 0, "Hello world!", 1) # invalid mode
    @test_throws EncodeError print(code)
    
    ## invalid mask or version
    code = QRCode("你好")
    @test code.mode == UTF8()
    code.mode = Alphanumeric()
    @test_throws EncodeError print(code)

    code = QRCode("你好")
    @test code.version == 1
    code.version = 0
    @test_throws EncodeError print(code)
    code.version = 41
    @test_throws EncodeError print(code)

    ## compare to the original method
    alphabets = [join('0':'9'), keys(alphanumeric), join(Char.(0:255)), keys(kanji), Char]
    for (mode, alphabet) in zip(modes, alphabets), eclevel in eclevels
        cap = last(characterscapacity[(eclevel, mode)])
        msg = join(rand(alphabet, rand(1:cap)))
        mat = qrcode(msg, eclevel=eclevel, mode=mode, width=1)
        code = QRCode(msg; eclevel=eclevel, mode=mode, width=1)
        @test mat == qrcode(code)
    end
    for (mode, alphabet) in zip(modes, alphabets), version in 1:3:40
        eclevel = Medium()
        cap = last(characterscapacity[(eclevel, mode)])
        msg = join(rand(alphabet, rand(1:cap)))
        mat = qrcode(msg, eclevel=eclevel, mode=mode, version=version, width=0)
        code = QRCode(msg; eclevel=eclevel, mode=mode, version=version, width=0)
        @test mat == qrcode(code)
    end

    # curry apply
    code = QRCode("Hello world!", width=0)
    code |> qrcode |> addborder(2) |> exportbitmat(imgpath * "qrcode-curry")
end

@testset "Generate QRCode -- small cases" begin
    ## Byte mode
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.png")
    exportqrcode("¬>=<×÷±+®©αβ", imgpath * "qrcode-sym.png")
    @test true
    ## UTF8 mode
    exportqrcode("你好", imgpath * "qrcode-你好.png")
    exportqrcode("123αβ", imgpath * "qrcode-123ab.png")
    @test true
    ## Kanji mode
    exportqrcode("茗荷", imgpath * "qrcode-茗荷.png")
    exportqrcode("瀚文", imgpath * "qrcode-瀚文.png")
    @test true
    ## Alphanumeric mode
    exportqrcode("HELLO WORLD", imgpath * "qrcode-hello.png")
    exportqrcode("123ABC", imgpath * "qrcode-123abc.png")
    @test true
    ## Numeric mode
    exportqrcode("8675309", imgpath * "qrcode-8675309.png")
    exportqrcode("0123456789", imgpath * "qrcode-0123456789.png")
    @test true
end

@testset "Generate QRCode -- large cases" begin
    ## Byte mode
    exportqrcode("0123456789:;<=>?@ABCDEFGHIJKLMNOPQRS"*
    "TUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz" ^ 3, imgpath * "qrcode-byte.png"; eclevel= Quartile())
    @test true

    ## UTF8 mode -- 两 ∉ kanji
    txt = "一个和尚打水喝，两个和尚没水喝" ^ 10
    exportqrcode(txt, imgpath * "qrcode-utf-8.png"; eclevel = Quartile())
    @test true
    
    ## Kanji mode
    txt = "一个和尚打水喝，二个和尚没水喝" ^ 10
    exportqrcode(txt, imgpath * "qrcode-kanji.png")
    @test true

    ## Alphanumeric mode
    exportqrcode("Lorem ipsum dolor sit amet, consectetur adipisicing elit,sed do eiusmod"*
    " tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nos" *
    "trud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irur"*
    "e dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."*
    " Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt "*
    "mollit anim id est laborum.", imgpath * "qrcode-alphanum.png")
    @test true

    ## Numeric mode
    exportqrcode("123456789000"^8, imgpath * "qrcode-num.png")
    @test true
end

@testset "Generate QRCode -- image extensions" begin
    ## Byte mode
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.png")
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.gif")
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.jpg")
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.jpeg")
    @test true
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.svg")
    
    ## UTF8 mode
    exportqrcode("你好αβ", imgpath * "qrcode-helloab.png")
    exportqrcode("你好αβ", imgpath * "qrcode-helloab.gif")
    exportqrcode("你好αβ", imgpath * "qrcode-helloab.jpg")
    @test true
    @test_throws EncodeError exportqrcode("你好αβ", imgpath * "qrcode-helloab.svg")
    
    ## Kanji mode
    exportqrcode("瀚文茗荷", imgpath * "qrcode-瀚文茗荷.png")
    exportqrcode("瀚文茗荷", imgpath * "qrcode-瀚文茗荷.gif")
    exportqrcode("瀚文茗荷", imgpath * "qrcode-瀚文茗荷.jpg")
    @test true
    @test_throws EncodeError exportqrcode("瀚文茗荷", imgpath * "qrcode-瀚文茗荷.svg")
    
    ## Alphanumeric mode
    exportqrcode("HELLO WORLD 123", imgpath * "qrcode-hello123.png")
    exportqrcode("HELLO WORLD 123", imgpath * "qrcode-hello123.gif")
    exportqrcode("HELLO WORLD 123", imgpath * "qrcode-hello123.jpg")
    @test true
    @test_throws EncodeError exportqrcode("HELLO WORLD 123", imgpath * "qrcode-hello123.svg")
    
    ## Numeric mode
    exportqrcode("123456789", imgpath * "qrcode-123456789.png")
    exportqrcode("123456789", imgpath * "qrcode-123456789.gif")
    exportqrcode("123456789", imgpath * "qrcode-123456789.jpg")
    @test true
    @test_throws EncodeError exportqrcode("123456789", imgpath * "qrcode-123456789.svg")

    ## Unsupported image format
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.bmp")
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.webp")
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.tiff")
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.psd")
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.pdf")
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.eps")
    @test_throws EncodeError exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.ai")

    ## invalid keys in future works
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.png", targetsize=5)
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.gif", targetsize=5)
    exportqrcode("Hello, world!", imgpath * "qrcode-helloworld.jpg", targetsize=5)
    exportqrcode(["julia", "is", "fast"], imgpath * "qrcode-hellojulia.gif", targetsize=5)
end

@testset "Generate QRCode -- animated images" begin
    # Numeric mode
    msg = "123456789"
    msgs = [msg[1:i] for i in 1:length(msg)]
    exportqrcode(msgs, imgpath * "qrcode-123456789.gif", fps=5)
    @test true

    # Alphanumeric mode
    msg = "HELLO WORLD 123"
    msgs = [msg[1:i] for i in 1:length(msg)]
    exportqrcode(msgs, imgpath * "qrcode-hello123.gif", fps=5)
    @test true

    # Byte mode
    msg = "Hello, world!"
    msgs = [msg[1:i] for i in 1:length(msg)]
    exportqrcode(msgs, imgpath * "qrcode-helloworld.gif", fps=5)
    @test true

    # UTF8 mode
    msg = collect("你好αβ")
    msgs = [join(msg[1:i]) for i in 1:length(msg)]
    exportqrcode(msgs, imgpath * "qrcode-helloab.gif", fps=2)
    @test true

    # Kanji mode
    msg = collect("瀚文茗荷")
    msgs = [join(msg[1:i]) for i in 1:length(msg)]
    exportqrcode(msgs, imgpath * "qrcode-瀚文茗荷.gif", fps=2)
    @test true

    # large image
    msgs = [join(rand('0':'9', 5596)) for _ in 1:5];
    codes = QRCode.(msgs, version=40, width=4);
    exportqrcode(codes, imgpath * "qrcodes.gif")
    @test true

    # test failed
    exportqrcode(msgs, imgpath * "qrcode-瀚文茗荷", fps=2) # no extension
    @test_throws EncodeError exportqrcode(msgs, imgpath * "qrcode-瀚文茗荷.jpg", fps=2) # invalid extension
end

@testset "Generate QRCode -- demo (Numeric)" begin
    alphabet = join('0':'9')
    msg = join(rand(alphabet, rand(1:5596)))

    # options
    eclevel = Medium()
    mode = getmode(msg)
    @test mode == Numeric()
    version = getversion(msg, mode, eclevel)

    # Mode indicator
    modeindicator = modeindicators[mode]

    # Character count: part of the encoded message
    msglen = length(msg)
    ccindicator = getcharactercountindicator(msglen, version, mode)

    # Encoded data: main part of the encoded message
    encodeddata = encodedata(msg, mode)

    # Getting parameters for the error correction
    necwords, nb1, nc1, nb2, nc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * nc1 + nb2 * nc2)

    # Pad encoded message before error correction
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)
    @test length(encoded) == requiredbits

    # Getting error correction codes
    blocks = makeblocks(encoded, nb1, nc1, nb2, nc2)
    ecblocks = getecblock.(blocks, necwords)

    # Interleave code blocks
    msgbits = interleave(blocks, ecblocks, necwords, nb1, nc1, nb2, nc2, version)
    @test length(msgbits) == requiredbits + necwords * (nb1 + nb2) * 8 + remainderbits[version]

    # Pick the best mask
    matrix = emptymatrix(version)
    masks = makemasks(matrix)
    matrix = placedata!(matrix, msgbits)
    addversion!(matrix, version)

    # Apply mask and add format information
    maskedmats = [addformat!(xor.(matrix, mat), i-1, eclevel) 
                  for (i, mat) in enumerate(masks)]
    scores = penalty.(maskedmats)
    mask = argmin(scores) - 1
    matrix = maskedmats[mask + 1]

    mat = qrcode(msg)
    @test penalty(matrix) == minimum(scores)
    @test mat == matrix
end