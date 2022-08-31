# original tests at QRCode.jl

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
    ecblocks = map(b->getecblock(b, ncodewords), blocks)
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
                matrix = qrcode(str, eclevel=eclevel)
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
