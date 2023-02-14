# interact with ZBar.jl

#=
Note for ZBar.jl
    1. `decodeimg` works for multiple QR codes in one image(some message failed in `--xml` mode)
    2. `decodesingle` works for single QR code in one image(some message might be misleading in `--noxml` mode)
=#

testzbar = "testimages/zbar/"
mkpath(testzbar)

@testset "Decode mode" begin
    # Numeric mode
    txt = join(rand(0:9, 10))
    exportqrcode(txt, "$testzbar/numeric.png")
    @test decodesingle("$testzbar/numeric.png") == txt
    @test decodeimg("$testzbar/numeric.png")[1] == txt
    txtall = join(0:9)
    exportqrcode(txtall, "$testzbar/allnumeric.png")
    @test decodesingle("$testzbar/allnumeric.png") == txtall
    @test decodeimg("$testzbar/allnumeric.png")[1] == txtall

    # Alphanumeric mode
    txt = join(rand(keys(alphanumeric), 10))
    exportqrcode(txt, "$testzbar/alphanum.png")
    @test decodesingle("$testzbar/alphanum.png") == txt
    @test decodeimg("$testzbar/alphanum.png")[1] == txt
    txtall = join(keys(alphanumeric))
    exportqrcode(txtall, "$testzbar/allalphanum.png")
    @test decodesingle("$testzbar/allalphanum.png") == txtall
    @test decodeimg("$testzbar/allalphanum.png")[1] == txtall

    # Byte mode -- ASCII
    txt = join(rand(Char.(0:127), 10))
    exportqrcode(txt, "$testzbar/byte-ascii.png")
    @test decodesingle("$testzbar/byte-ascii.png") == txt
    ## decodeimg misdecode some message
    @test_broken decodeimg("$testzbar/byte-ascii.png")[1] == txt

    txtall = join(Char.(0:127))
    exportqrcode(txtall, "$testzbar/allbyte-ascii.png")
    @test decodesingle("$testzbar/allbyte-ascii.png") == txtall
    ## decodeimg misdecode some message
    @test_broken decodeimg("$testzbar/allbyte-ascii.png")[1] == txtall

    # Byte mode -- 128-255
    txt = "©®±²³"
    exportqrcode(txt, "$testzbar/byte-128-255.png")
    ## zbar use different encoding for 0xf0-0xff
    @test_broken decodesingle("$testzbar/byte-128-255.png") == txt
    @test_broken decodeimg("$testzbar/byte-128-255.png")[1] == txt

    # UTF8 -- ZBar do not support UTF8
    txt = "你好"
    exportqrcode(txt, "$testzbar/utf8.png")
    @test_broken decodesingle("$testzbar/utf8.png") == txt
    @test_broken decodeimg("$testzbar/utf8.png")[1] == txt

    # Kanji mode
    txt = "茗荷"
    exportqrcode(txt, "$testzbar/kanji.png")
    @test decodesingle("$testzbar/kanji.png") == txt
    ## decodeimg misdecode some message
    @test_broken decodeimg("$testzbar/kanji.png")[1] == txt
end


@testset "Same message by different encoding" begin
    # ASCII vs 128-255
    txt = "©®±²³"
    exportqrcode(txt, "$testzbar/ascii-128-255.png")
    ## zbar use different encoding for 0xf0-0xff
    @test_broken decodesingle("$testzbar/ascii-128-255.png") == txt
    @test_broken decodeimg("$testzbar/ascii-128-255.png")[1] == txt

    # ASCII vs UTF8
    txt = "你好"
    exportqrcode(txt, "$testzbar/ascii-utf8.png")
    @test_broken decodesingle("$testzbar/ascii-utf8.png") == txt
    @test_broken decodeimg("$testzbar/ascii-utf8.png")[1] == txt
end

@testset "Same message with different setting" begin
    message = "Hello, world!"
    for v in 1:5, eclevel in eclevels, mask in 0:7
        exportqrcode(message, "$testzbar/v$(v)-m$(mask).png"; version=v, eclevel=eclevel, mask=mask)
        @test decodesingle("$testzbar/v$(v)-m$(mask).png") == message == decodeimg("$testzbar/v$(v)-m$(mask).png")[1]
    end
    for v in vcat(1:33, [35, 36, 40])
        exportqrcode(message, "$testzbar/version$v.png", version=v)
        @test decodesingle("$testzbar/version$v.png") == message
        @test decodeimg("$testzbar/version$v.png")[1] == message
    end

    # ZBar fail to detect QR code when the version is too large
    for v in [34, 37, 38, 39]
        exportqrcode(message, "$testzbar/version$v.png", version=v)
        @test_broken decodesingle("$testzbar/version$v.png") == message
        @test_broken decodeimg("$testzbar/version$v.png")[1] == message
    end
end