@testset "Encoding modes" begin
    @test getmode("2983712983") == Numeric()
    @test getmode("ABCDEFG1234 \$%*+-./:") == Alphanumeric()
    @test getmode("ABC,") == Byte()
    @test getmode("ABCabc") == Byte()
    @test getmode("αβ") == Kanji() ## letters "αβ" are not support in Byte() mode
    @test_throws DomainError getmode("123αβ") # mix type of digits and Kanji characters
    @test_throws DomainError getmode("你好") # unsupported character '你'
end

@testset "Capacity of the QRCode -- getversion " begin
    tag = true
    for ((ec, mode), arr) in characterscapacity
        mode != Numeric() && continue
        for (v, cap) in enumerate(arr)
            if !tag || getversion(join(rand('0':'9', v)), Numeric(), ec) == v
                tag = false
                break
            end
            @test_throws EncodeError getversion(join(rand('0':'9', v + 1)), Numeric(), ec)
        end
    end
    @test tag
    alphabet = vcat('0':'Z', collect(" \$%*+-./:"))
    tag = true
    for ((ec, mode), arr) in characterscapacity
        mode != Alphanumeric() && continue
        for (v, cap) in enumerate(arr)
            if !tag || getversion(rand('A':'Z', v), Alphanumeric(), ec) == v
                tag = false
                break
            end
            @test_throws EncodeError getversion(rand('A':'Z', v + 1), Alphanumeric(), ec)
        end
    end
end
