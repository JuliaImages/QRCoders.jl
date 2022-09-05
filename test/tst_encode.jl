@testset "Encoding modes" begin
    @test getmode("2983712983") == Numeric()
    @test getmode("ABCDEFG1234 \$%*+-./:") == Alphanumeric()
    @test getmode("ABC,") == Byte()
    @test getmode("ABCabc") == Byte()
    @test getmode("αβ") == Kanji() ## letters "αβ" are not support in Byte() mode
    @test getmode("123αβ") == UTF8()
    @test getmode("你好") == UTF8()
end

@testset "Capacity of the QRCode -- getversion " begin
    modes = [Numeric(), Alphanumeric(), Byte(), Kanji()]
    alphabets = [join('0':'9'), keys(alphanumeric), join(Char.(0:255)), keys(kanji)]
    for (mode, alphabet) in zip(modes, alphabets)
        tag = true
        for ((ec, m), arr) in characterscapacity
            m != Numeric() && continue
            for (v, cap) in enumerate(arr)
                if !tag || getversion(join(rand(alphabet, cap)), m, ec) != v
                    tag = false
                    break
                end
            end
            @test_throws EncodeError getversion(join(rand(alphabet, last(arr) + 1)), m, ec)
        end
        @test tag
    end
end

## test cases from https://www.thonky.com/qr-code-tutorial/
@testset "Encode data -- message into bits" begin
    ## Numeric mode
    msg = "8675309"
    mode = Numeric()
    @test join(Int.(encodedata(msg, mode))) == "110110001110000100101001"

    ## Alphanumeric mode
    msg = "HELLO WORLD"
    mode = Alphanumeric()
    @test join(Int.(encodedata(msg, mode))) == "0110000101101111000110100010111001011011100010011010100001101"

    ## Byte mode
    msg = "Hello, world!"
    mode = Byte()
    @test join(Int.(encodedata(msg, mode))) == "010010000110010101101100" *
    "01101100011011110010110000100000011101110110111101110010011011000110010000100001"

    ## Kanji mode
    msg = "茗荷"
    mode = Kanji()
    @test join(Int.(encodedata(msg, mode))) == "11010101010100011010010111"

    ## UTF-8 mode
end

@testset "Indicator and pad codes" begin
    ## getcharactercountindicator, padencodedmessage
    modes = [Numeric(), Alphanumeric(), Byte(), Kanji()]
    alphabets = [join('0':'9'), vcat('0':'Z', collect(" \$%*+-./:")), join(Char.(0:255)), keys(kanji)]
    v = rand(1:40)
    i = (v ≥ 1) + (v ≥ 10) + (v ≥ 27)
    for (mode, alphabet) in zip(modes, alphabets)
        cclength = charactercountlength[mode][i]
        msglen = rand(1:cclength)
        msg = join(rand(alphabet, msglen))
        indicator = getcharactercountindicator(length(msg), v, mode)
        @test length(indicator) == cclength && bitarray2int(indicator) == msglen
    end
    @test_throws EncodeError padencodedmessage(BitArray{1}(rand(Bool, 10)), 9)
end

@testset "Generate QRCode -- small cases" begin
    ## Byte mode
    exportqrcode("Hello, world!", "qrcode-helloworld.png")
    exportqrcode("¬>=<×÷±+®©αβ", "qrcode-sym.png")
    @test true
    ## UTF8 mode
    exportqrcode("你好", "qrcode-你好.png")
    exportqrcode("123αβ", "qrcode-123ab.png")
    @test true
    ## Kanji mode
    exportqrcode("茗荷", "qrcode-茗荷.png")
    exportqrcode("瀚文", "qrcode-瀚文.png")
    @test true
    ## Alphanumeric mode
    exportqrcode("HELLO WORLD", "qrcode-hello.png")
    exportqrcode("123ABC", "qrcode-123abc.png")
    @test true
    ## Numeric mode
    exportqrcode("8675309", "qrcode-8675309.png")
    exportqrcode("0123456789", "qrcode-0123456789.png")
    @test true
end

@testset "Generate QRCode -- large cases" begin
    ## Byte mode
    exportqrcode("0123456789:;<=>?@ABCDEFGHIJKLMNOPQRS"*
    "TUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz" ^ 3, "qrcode-byte.png"; eclevel= Quartile())
    @test true

    ## UTF8 mode -- 两 ∉ kanji
    txt = "一个和尚打水喝，两个和尚没水喝" ^ 10
    exportqrcode(txt, "qrcode-utf-8.png"; eclevel = Quartile())
    @test true
    
    ## Kanji mode
    txt = "一个和尚打水喝，二个和尚没水喝" ^ 10
    exportqrcode(txt, "qrcode-kanji.png")
    @test true

    ## Alphanumeric mode
    exportqrcode("Lorem ipsum dolor sit amet, consectetur adipisicing elit,sed do eiusmod"*
    " tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nos" *
    "trud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irur"*
    "e dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."*
    " Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt "*
    "mollit anim id est laborum.", "qrcode-alphanum.png")
    @test true

    ## Numeric mode
    exportqrcode("123456789000"^8, "qrcode-num.png")
    @test true
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
    ncodewords, nb1, nc1, nb2, nc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * nc1 + nb2 * nc2)

    # Pad encoded message before error correction
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)
    @test length(encoded) == requiredbits

    # Getting error correction codes
    blocks = makeblocks(encoded, nb1, nc1, nb2, nc2)
    ecblocks = getecblock.(blocks, ncodewords)

    # Interleave code blocks
    msgbits = interleave(blocks, ecblocks, ncodewords, nb1, nc1, nb2, nc2, version)
    @test length(msgbits) == requiredbits + ncodewords * (nb1 + nb2) * 8 + remainderbits[version]

    # Pick the best mask
    matrix = emptymatrix(version)
    masks = makemasks(matrix)
    matrix = placedata!(matrix, msgbits)
    candidates = map(enumerate(masks)) do (i, m)
        i - 1, xor.(matrix, m)
    end
    mask, matrix = first(sort(candidates, by = penalty ∘ last))
    matrix = addformat(matrix, mask, version, eclevel)

    mat = qrcode(msg;eclevel= Medium(), compact=true)
    @test mat == matrix
end

@testset "Byte VS UTF8 mode " begin
    ## for ascii characters -- return the same QRCode
    alphabet = join(Char.(0:127))
    eclevels = [Low(), Medium(), Quartile(), High()]
    for eclevel in eclevels
        cap = last(characterscapacity[(eclevel, Byte())])
        msg = join(rand(alphabet, rand(cap:cap)))
        @test qrcode(msg;eclevel=eclevel, mode=UTF8()) == qrcode(msg;eclevel=eclevel, mode=Byte())
    end
end