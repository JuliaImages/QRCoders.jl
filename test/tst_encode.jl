@testset "Encoding modes" begin
    @test getmode("2983712983") == Numeric()
    @test getmode("ABCDEFG1234 \$%*+-./:") == Alphanumeric()
    @test getmode("ABC,") == Byte()
    @test getmode("ABCabc") == Byte()
    @test getmode("αβ") == Kanji() ## letters "αβ" are not support in Byte() mode
    @test getmode("123αβ") == UTF8()
    @test getmode("你好") == UTF8()
    # @test_throws DomainError getmode("123αβ") # mix type of digits and Kanji characters
    # @test_throws DomainError getmode("你好") # unsupported character '你'
end

@testset "Capacity of the QRCode -- getversion " begin
    modes = [Numeric(), Alphanumeric(), Byte(), Kanji()]
    alphabets = [join('0':'9'), vcat('0':'Z', collect(" \$%*+-./:")), join(Char.(0:255)), keys(kanji)]
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

@testset "Encode message -- message bits into data bits" begin
    
end

@testset "Generate QRCode" begin
    ## Byte mode
    exportqrcode("Hello, world!", "helloworld.png")
    exportqrcode("¬>=<×÷±+®©αβ", "sym.png")
    @test true
    ## UTF8 mode
    exportqrcode("你好", "你好.png")
    exportqrcode("123αβ", "123ab.png")
    @test true
    ## Kanji mode
    exportqrcode("茗荷", "茗荷.png")
    exportqrcode("瀚文", "瀚文.png")
    @test true
    ## Alphanumeric mode
    exportqrcode("HELLO WORLD", "hello.png")
    exportqrcode("123ABC", "123abc.png")
    @test true
    ## Numeric mode
    exportqrcode("8675309", "8675309.png")
    exportqrcode("0123456789", "0123456789.png")
    @test true
end