# Test for style of QR code
@testset "Unicode plot" begin
    # by UnicodePlots
    alphabets = [join('0':'9'), keys(alphanumeric), join(Char.(0:255)), keys(kanji)]
    for alphabet in alphabets
        msg = join(rand(alphabet, 100))
        canvas = unicodeplot(msg)
    end
    @test true

    # by Unicode characters
    alphabets = [join('0':'9'), keys(alphanumeric), join(Char.(0:255)), keys(kanji)]
    for alphabet in alphabets
        msg = join(rand(alphabet, 100))
        canvas = unicodeplotbychar(msg)
    end
    @test true
end

@testset "locate msg bits" begin
    # length of message bits
    @test msgbitslen == [length(encodemessage("a", Byte(), High(), i)) for i in 1:40]

    # common settings
    mode, eclevel = Alphanumeric(), Quartile()
    msg = "HELLO WORLD"

    # extract indexes of message bits
    for v in 1:40
        data = encodemessage(msg, mode, eclevel, v)
        @test length(data) == msgbitslen[v]
        # generate QR matrix
        mat = qrcode(msg, mode=mode, eclevel=eclevel, version=v, mask=0, width=0)
        # remove mask
        mat = xor.(makemask(emptymatrix(v), 0), mat)
        # indexes of message bits
        inds = getindexes(v)
        @test mat[inds] == data
    end

    # get segments of the QR code
    for v in 1:40
        necwords, nb1, nc1, nb2, nc2 = ecblockinfo[eclevel][v, :]
        requiredbits = 8 * (nb1 * nc1 + nb2 * nc2)
        segments, ecsegments = getsegments(v, eclevel)
        msginds = vcat(segments...)
        ecinds = vcat(ecsegments...)
        ## check the length of message segments
        @test length(msginds) == requiredbits
        
        # test for QR matrix
        ## read from encoding process
        modeindicator = modeindicators[mode]
        ccindicator = getcharactercountindicator(length(msg), v, mode)
        encodeddata = encodedata(msg, mode)
        encoded = vcat(modeindicator, ccindicator, encodeddata)
        encoded = padencodedmessage(encoded, requiredbits)
        ## read from QR matrix
        mat = qrcode(msg, mode=mode, eclevel=eclevel, version=v, mask=0, width=0)
        mat = xor.(makemask(emptymatrix(v), 0), mat)
        msgbits = mat[msginds]
        @test encoded == msgbits
    end
end

@testset "display -- use white modules in msgbits" begin
    # common settings
    mode, eclevel = Alphanumeric(), Quartile()
    msg = "HELLO WORLD"
    mat = qrcode(msg, mode=mode, eclevel=eclevel, version=7, mask=0, width=0)
    segments, ecsegments = getsegments(7, eclevel)
    msginds = vcat(segments...)
    ecinds = vcat(ecsegments...)
    mat[msginds] .= 1
    mat[ecinds] .= 1
    unicodeplotbychar(mat) |> println
    @test true
end

@testset "simulate image" begin
    # image in qrcode
    img = testimage("cam")
    img = .!(Bool.(round.(imresize(img, 37, 37))))
    code = QRCode("HELLO WORLD", eclevel=High(), version=16, width=4)
    mat = imagebyerrcor(code, img, rate=2/3)
    exportbitmat(mat, "testimages/cam.png")
    @test true
    mat = imagebyerrcor("hello world!", img, version=10, width=2, rate=1.1)
    mat |> unicodeplotbychar |> println
    @test true

    # test for animate
    code = QRCode("HELLO WORLD", eclevel=High(), version=16, width=4)
    code2 = QRCode("Hello julia!", eclevel=High(), version=16, width=4)
    codes = [code, code2]
    animatebyerrcor(codes, [img, img], "testimages/cam.gif", rate=2/3)
    @test true
end
