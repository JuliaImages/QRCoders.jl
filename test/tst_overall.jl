@testset "Exporting a QR code to multiple file formats." begin
    message = "To be or not to be a QR code?"
    # supported types
    for ext in ["", "jpg", "png"]
        exportqrcode(message, imgpath * "qrcode-test.$ext")
    end
    @test true
    # unsupported type
    @test_throws EncodeError exportqrcode(message, "qrcode-test.svg")
end

@testset "Exporting all visible ISO-8859-1 characters" begin
    message = join(Char.(vcat(0x20:0x7e, 0xa0:0xff)))
    exportqrcode(message, imgpath * "qrcode-ISO-8859-1-test.png")
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
    necwords, nb1, dc1, nb2, dc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * dc1 + nb2 * dc2)
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)
    blocks = makeblocks(encoded, nb1, dc1, nb2, dc2)
    ecblocks = map(b->getecblock(b, necwords), blocks)
    data0 = interleave(blocks, ecblocks, necwords, nb1, dc1, nb2, dc2, version)
    matrix0 = emptymatrix(version)
    masks = makemasks(matrix0)
    image = falses((39,39*8))
    for (i, mask) in enumerate(masks)
        matrix = deepcopy(matrix0)
        data = deepcopy(data0)
        matrix = placedata!(matrix, data)
        matrix = xor.(mask, matrix)
        addversion!(matrix, version)
        addformat!(matrix, i-1, eclevel)
        image[5:33, (i-1)*39+1:(i-1)*39+29] = matrix
    end
    img = colorview(Gray, .! image)
    save(imgpath * "qrcode-masks.png", img)
    @test true
end

@testset "Generating masks" begin
    function origin_makemasks(matrix::Array{Union{Bool,Nothing},2})::Array{BitArray{2},1}
        n = size(matrix, 1)
        masks = [falses(size(matrix)) for _ in 1:8]
    
        # Weird indexing due to 0-based indexing in documentation
        for row in 0:n-1, col in 0:n-1
            isnothing(matrix[row+1, col+1]) || continue
            if (row ⊻ col) & 1 == 0
                masks[1][row+1, col+1] = true
            end
            if row & 1 == 0
                masks[2][row+1, col+1] = true
            end
            if col % 3 == 0
                masks[3][row+1, col+1] = true
            end
            if (row + col) % 3 == 0
                masks[4][row+1, col+1] = true
            end
            if (row >> 1 + col ÷ 3) & 1 == 0
                masks[5][row+1, col+1] = true
            end
            if (row & col & 1) + ((row * col) % 3) == 0
                masks[6][row+1, col+1] = true
            end
            if ((row & col & 1) + ((row * col) % 3)) & 1 == 0
                masks[7][row+1, col+1] = true
            end
            if (((row ⊻ col) & 1) + ((row * col) % 3)) & 1 == 0
                masks[8][row+1, col+1] = true
            end
        end
        return masks
    end

    tag = true
    for v in 1:40
        matrix = emptymatrix(v)
        if makemasks(matrix) != origin_makemasks(matrix)
            tag = false
            break
        end
    end
    @test tag
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
                matrix = qrcode(str, eclevel=eclevel, width=4)
                nm = size(matrix, 2)
                image[i*s+1:i*s+nm, j*s+1:j*s+nm] = matrix
            end
            path = imgpath * "qrcode-$(typeof(mode))-$(typeof(eclevel))-versions.png"
            save(path, colorview(Gray, .! image))
            println("$path created")
        end
    end
    @test true
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


    char2bit(c) = c != '0'
    bits5Q = BitArray(map(char2bit, collect(data5Q)))
    bits5Qf = BitArray(map(char2bit, collect(final5Q)))

    blocks = makeblocks(bits5Q, 2, 15, 2, 16)
    errcorrblocks = map(b -> getecblock(b, 18), blocks)
    data = interleave(blocks, errcorrblocks, 18, 2, 15, 2, 16, 5)

    @test data == bits5Qf
end
