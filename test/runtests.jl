using QRCode
using Test
using Images
using Random

import QRCode: makeblocks, geterrcorrblock, interleave, emptymatrix,
               characterscapacity, modeindicators, getcharactercountindicator,
               encodedata, ecblockinfo, padencodedmessage, makemasks, addformat,
               placedata!
import QRCode.Polynomial: Poly, antilogtable, logtable, generator,
                          geterrorcorrection

@testset "Test set for encoding modes" begin
    @test getmode("2983712983") == Numeric()
    @test getmode("ABCDEFG1234 \$%*+-./:") == Alphanumeric()
    @test getmode("ABC,") == Byte()
    @test getmode("ABCabc") == Byte()
    @test getmode("αβ") == Byte()
end

@testset "Test set for polynomials and error encoding" begin
    for i in 0:254
        @test i == antilogtable[logtable[i]]
    end

    for i in 1:255
        @test i == logtable[antilogtable[i]]
    end

    p = Poly(rand(UInt8, 10))
    q = Poly(rand(UInt8, 20))
    @test Poly([1]) * p == p
    @test p * q == q * p
    @test p + q == q + p

    @test p + p == Poly(zeros(UInt8, 10))

    @test Poly([1, 1]) * Poly([2, 1]) == Poly([2, 3, 1])
    @test Poly([1, 1]) * Poly([2, 1]) * Poly([4, 1]) == Poly([8, 14, 7, 1])

    @test generator(2) == Poly([2, 3, 1])
    @test generator(3) == Poly([8, 14, 7, 1])

    g7 = [21, 102, 238, 149, 146, 229, 87, 0]
    @test generator(7) == Poly(map(n -> logtable[n], g7))

    g8 = [28, 196, 252, 215, 249, 208, 238, 175, 0]
    @test generator(8) == Poly(map(n -> logtable[n], g8))

    g9 = [36, 123, 11, 149, 235, 231, 137, 246, 95, 0]
    @test generator(9) == Poly(map(n -> logtable[n], g9))

    g12 = [66, 157, 87, 131, 143, 198, 113, 187, 121, 98, 43, 102, 0]
    @test generator(12) == Poly(map(n -> logtable[n], g12))

    msg = [17, 236, 17, 236, 17, 236, 64, 67, 77, 220, 114, 209, 120, 11, 91, 32]
    r = [23, 93, 226, 231, 215, 235, 119, 39, 35, 196]
    @test geterrorcorrection(Poly(msg), 10) == Poly(r)

    msg = [70,247,118,86,194,6,151,50,16,236,17,236,17,236,17,236]
    r = [235, 159, 5, 173, 24, 147, 59, 33, 106, 40, 255, 172, 82, 2,
         131, 32, 178, 236]
    @test geterrorcorrection(Poly(reverse(msg)), 18) == Poly(reverse(r))
end

@testset "Test set for error correction and interleaving" begin

    data5Q = *( "010000110101010101000110100001100101011100100110010"
              , "101011100001001110111001100100000011000010010"
              , "0000011001100111001001101111011011110110010000100"
              , "0000111011101101000011011110010000001110010011001010110"
              , "00010110110001101100011110010010000001101011011011100110"
              , "11110111011101110011001000000111011101101000011001010111"
              , "0010011001010010000001101000011010010111001100100000011"
              , "101000110111101110111011001010110110000100000011010010111001"
              , "10010000100001110110000010001111011000001000111101100000"
              , "1000111101100" )

    final5Q = *( "0100001111110110101101100100011001010101111101101110011"
               , "01111011101000110010000101111011101110110100001100000"
               , "011101110111010101100101011101110110001100101100001000100"
               , "1101000011000000111000001100101010111110010011101101"
               , "001011111000010000001111000011000110010011101110"
               , "0100110010101110001000000110010010101100010011011101100"
               , "0000011000010110010100100001000100010010110001100000011011"
               , "101100000001101100011110000110000100010110011110"
               , "01001010010111111011000010011000000110001100100001000"
               , "1000001111110110011010101010101111001010011101011110"
               , "001111100110001110100100111110000101101100000101100010000010"
               , "10010110100111100110101001010110101110011110010100100"
               , "11000001100011110111101101101000010110010011111100010111110"
               , "001001011001110111101111110011101111100100010000111100101"
               , "11001000111011100110101011111000100001100100110000101000100"
               , "1101000011011110000111111111101110101100000011110011010101"
               , "100100110101101000110111101010100100110111100010001000010"
               , "100000001001010110101000110110110010000011101000011010001"
               , "111110000001000000110111101111000110000001011001000100111100"
               , "0010110001101111011000000000" )


    char2bit(c) = c == '0' ? false : true
    bits5Q = BitArray(map(char2bit, collect(data5Q)))
    bits5Qf = BitArray(map(char2bit, collect(final5Q)))

    blocks = makeblocks(bits5Q, 2, 15, 2, 16)
    errcorrblocks = map(b -> geterrcorrblock(b, 18), blocks)
    data = interleave(blocks, errcorrblocks, 18, 2, 15, 2, 16, 5)

    @test data == bits5Qf
end

@testset "Exporting a QR code" begin
    message = "To be or not to be a QR code?"
    exportqrcode(message, "qrcode-test.png")
    @test true
end

@testset "Exporting all visible ISO-8859-1 characters" begin
    message = *( "µÞþŽžZzŸÿÝýYyXxWwVvÜüÛûÙùÚúUu™TtßŠšSsRrQqPpŒœØøÕõÖöÔôÒòÓ"
               , "óOoºÑñNnMmLlKkJjÏïÎîÌìÍíIiHhGgƒFfËëÊêÈèÉéEeÐðDdÇçCcBbÆæÃ"
               , "ãÄäÅåÂâÀàÁáAaª¾³²¼½¹€¥£\$¢¤~¦|¬>=<×÷±+®©°ˆ¸¨¯^˜´`•‡†‰%#&\\/"
               , "*@¶§}{][)(»«„”“\"›‹·….¿?¡!:;,—–-_9876543210"
               )
    exportqrcode(message, "qrcode-ISO-8859-1-test.png")
    @test true
end

@testset "Generating QR codes to test different masks" begin
    message = "To be or not to be a QR code?"
    eclevel = Quartile()
    mode = Byte()
    version = getversion(message, mode, eclevel)
    modeindicator = modeindicators[mode]
    ccindicator = getcharactercountindicator(length(message), version, mode)
    encodeddata = encodedata(message, mode)
    ncodewords, nb1, dc1, nb2, dc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * dc1 + nb2 * dc2)
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)
    blocks = makeblocks(encoded, nb1, dc1, nb2, dc2)
    ecblocks = map(b->geterrcorrblock(b, ncodewords), blocks)
    data0 = interleave(blocks, ecblocks, ncodewords, nb1, dc1, nb2, dc2, version)
    matrix0 = emptymatrix(version)
    masks = makemasks(matrix0)
    image = falses((39,39*8))
    for (i, mask) in enumerate(masks)
        matrix = deepcopy(matrix0)
        data = deepcopy(data0)
        matrix = placedata!(matrix, data)
        matrix = xor.(mask, matrix)
        matrix = addformat(matrix, i-1, version, eclevel)
        image[5:33, (i-1)*39+1:(i-1)*39+29] = matrix
    end
    img = colorview(Gray, .! image)
    save("qrcode-masks.png", img)
    @test true
end

@testset "Generating QR codes to test with QR codes reader" begin
    s = 185 # maximum width of a QR code
    for eclevel in [Low(), Medium(), Quartile(), High()]
        for mode in [Numeric(), Alphanumeric(), Byte()]
            image = falses(s*5, s*8)
            for i in  0:4, j in 0:7
                version = i*8 + j + 1
                l = characterscapacity[(eclevel, mode)][version]
                if mode == Numeric()
                    str = randstring('0':'9', l)
                elseif mode == Alphanumeric()
                    str = randstring(vcat('0':'9', 'A':'Z', collect(" %*+-./:\$")), l)
                else
                    str = randstring(l)
                end
                matrix = qrcode(str, eclevel)
                nm = size(matrix, 2)
                image[i*s+1:i*s+nm, j*s+1:j*s+nm] = matrix
            end
            path = "qrcode-$(typeof(mode))-$(typeof(eclevel))-versions.png"
            save(path, colorview(Gray, .! image))
            println("$path created")
        end
    end
    @test true
end
