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
end

@testset "Indicator and pad codes" begin
    ## getcharactercountindicator, padencodedmessage
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

@testset "Byte VS UTF8 mode " begin
    ## for ascii characters -- return the same QRCode
    alphabet = join(Char.(0:127))
    
    for eclevel in eclevels
        cap = last(characterscapacity[(eclevel, Byte())])
        msg = join(rand(alphabet, rand(1:cap)))
        @test qrcode(msg;eclevel=eclevel, mode=UTF8()) == qrcode(msg;eclevel=eclevel, mode=Byte())
    end
end

# original penalty
function orgpenalty(matrix::BitArray{2})
    n = size(matrix, 1)

    # Condition 1: 5+ in a row of the same color
    function penalty1(line)
        consecutive, score, cur = 0, 0, -1
        for i in line
            if i == cur
                consecutive += 1
            else
                if consecutive ≥ 5
                    score += consecutive - 2
                end
                consecutive, cur = 1, i
            end
        end
        return score
    end
    p1 = sum(penalty1.(eachrow(matrix))) + sum(penalty1.(eachcol(matrix)))

    # Condition 2: number of 2x2 blocks of the same color
    p2 = 0
    for i in 1:n-1, j in 1:n-1
        block = matrix[i:i+1, j:j+1]
        if block[1] == block[2] == block[3] == block[4]
            p2 += 3
        end
    end

    # Condition 3: specific patterns in rows or columns
    p3 = 0
    patt1 = BitArray([1, 0, 1, 1, 1, 0, 1, 0, 0, 0 ,0])
    patt2 = BitArray([0, 0, 0 ,0, 1, 0, 1, 1, 1, 0, 1])
    for i in 1:n, j in 1:n - 10
        hline = matrix[i, j:j + 10]
        if hline == patt1 || hline == patt2
            p3 += 40
        end
        vline = matrix[j:j + 10, i]
        if vline == patt1 || vline == patt2
            p3 += 40
        end
    end

    # Condition 4: percentage of black and white
    t = sum(matrix) * 100 ÷ length(matrix) ÷ 5
    p4 = 10 * min(abs(t - 10), abs(t - 11))

    return p1 + p2 + p3 + p4
end

@testset "penalty of different masks" begin
    # test case -- debug
    msg = "αβ"
    mats = [qrcode(msg;mask=i) for i in 0:7]
    scores = penalty.(mats)
    mat = qrcode(msg);
    @test penalty(mat) == minimum(scores) == orgpenalty(mat)

    # test case -- Random
    alphabets = [join('0':'9'), keys(alphanumeric), join(Char.(0:255)), keys(kanji)]
    for (alphabet, mode) in zip(alphabets, modes), eclevel in eclevels
        cap = last(characterscapacity[(eclevel, mode)])
        msg = join(rand(alphabet, rand(1:cap)))
        mats = [qrcode(msg;eclevel=eclevel, mask=i) for i in 0:7]
        scores = penalty.(mats)
        mat = qrcode(msg;eclevel=eclevel);
        @test penalty(mat) == minimum(scores) == orgpenalty(mat)
    end
end