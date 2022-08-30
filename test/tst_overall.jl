# original tests at QRCode.jl

@testset "Test set for polynomials and error encoding" begin
    @test all(i == antilogtable[logtable[i]] for i in 0:254)
    @test all(i == logtable[antilogtable[i]] for i in 1:255)

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

@testset "Exporting a QR code" begin
    message = "To be or not to be a QR code?"
    exportqrcode(message, "qrcode-test.png")
    @test true
end

@testset "Exporting all visible ISO-8859-1 characters" begin
    message = join(Char.(0:255))
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
