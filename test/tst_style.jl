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

    # test for struct type QRCode
    code = QRCode("hello world!")
    unicodeplot(code)
    unicodeplotbychar(code)
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
        v = 1
        necwords, nb1, nc1, nb2, nc2 = ecblockinfo[eclevel][v, :]
        requiredbits = 8 * (nb1 * nc1 + nb2 * nc2)
        segments, ecsegments = getsegments(v, eclevel)
        msginds = vcat(vcat(segments...)...)
        ecinds = vcat(vcat(ecsegments...)...)
        ## check the length of message segments
        @test length(msginds) == requiredbits
        inds = getindexes(v)
        byteinds = vcat(msginds..., ecinds...)
        @test inds[1:length(byteinds)] == byteinds
        
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
    # dispatch for QRCode
    code = QRCode("hello world")
    @test getindexes(code) == getindexes(code.version)
end

@testset "display -- use white modules in msgbits" begin
    # common settings
    mode, eclevel = Alphanumeric(), Quartile()
    msg = "HELLO WORLD"
    mat = qrcode(msg, mode=mode, eclevel=eclevel, version=7, mask=0, width=0)
    segments, ecsegments = getsegments(7, eclevel)
    msginds = vcat(vcat(segments...)...)
    ecinds = vcat(vcat(ecsegments...)...)
    mat[msginds] .= 1
    mat[ecinds] .= 1
    unicodeplotbychar(mat) |> println
    @test true
end