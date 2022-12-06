@testset "locate QR matrix -- version & format" begin
    v, mask, eclevel = rand(7:40), rand(0:7), rand(eclevels)
    code = QRCode("hello", version=v, eclevel=eclevel, mask=mask, width=0)
    mat = qrcode(code)

    # test version
    vinds = getversioninds(code)
    vbits = mat[vinds]
    @test length(vbits) == 36
    @test vbits[1:18] == vbits[19:36]
    @test vbits[1:18] == qrversionbits(v)
    # test format
    finds = getformatinds(code)
    fbits = mat[finds]
    @test length(fbits) == 30
    @test fbits[1:15] == fbits[16:30]
    @test fbits[1:15] == qrformat(eclevel, mask)

    tag = true
    for v in 7:40, mask in 0:7, eclevel in eclevels
        code = QRCode("hello", version=v, eclevel=eclevel, mask=mask, width=0)
        mat = qrcode(code)
        vinds, finds = getversioninds(code), getformatinds(code)
        vbits, fbits = mat[vinds][1:18], mat[finds][1:15]
        vbits == qrversionbits(v) && fbits == qrformat(eclevel, mask) && continue
        tag = false
    end
    @test tag
end

@testset "locate QR matrix -- Function region" begin
    # general test
    ## timing pattern
    code = QRCode("hello", version=1, eclevel=Low(), mask=0, width=0)
    mat = qrcode(code)
    tinds = gettiminginds(code)
    half = qrwidth(code) - 14
    @test length(tinds) == 2 * half
    @test mat[tinds[1:half]] == mat[tinds[half+1:end]]
    @test mat[tinds[1:half]] == push!(repeat([false, true], half÷2), false)

    ## dark mode
    @test mat[getdarkindex(code)]

    ## alignment pattern
    algpos = getalignmentinds(code)
    algwidth = CartesianIndex(4, 4)
    for leftop in algpos
        @test mat[leftop:leftop+algwidth] == alignmentpattern
    end

    ## finder pattern
    fdpos = getfinderinds(code)
    fdwidth = CartesianIndex(6, 6)
    for leftop in fdpos
        @test mat[leftop:leftop+fdwidth] == finderpattern
    end

    ## seperators
    sepinds = getsepinds(code)
    @test !any(mat[sepinds])

    # test for all versions
    for v in 1:40
        code = QRCode("hello", version=v, width=0)
        mat = qrcode(code)
        tag = true
        # test timing pattern
        tinds = gettiminginds(code)
        half = qrwidth(code) - 14
        tag &= length(tinds) == 2 * half
        tag &= mat[tinds[1:half]] == mat[tinds[half+1:end]]
        tag &= mat[tinds[1:half]] == push!(repeat([false, true], half÷2), false)
        # test dark mode
        tag &= mat[getdarkindex(code)]
        # test alignment pattern
        algpos = getalignmentinds(code)
        algwidth = CartesianIndex(4, 4)
        for leftop in algpos
            tag &= mat[leftop:leftop+algwidth] == alignmentpattern
        end
        # test finder pattern
        fdpos = getfinderinds(code)
        fdwidth = CartesianIndex(6, 6)
        for leftop in fdpos
            tag &= mat[leftop:leftop+fdwidth] == finderpattern
        end
        # test seperators
        sepinds = getsepinds(code)
        tag &= !any(mat[sepinds])
        @test tag
    end
end

@testset "general build test" begin
    code = QRCode("hello world!", version=7, width=0)
    stdmat = qrcode(code)
    mat = zero(stdmat); # blank matrix

    # Finder pattern
    fdpos = getfinderinds(code)
    fdwidth = CartesianIndex(6, 6)
    for leftop in fdpos
        mat[leftop:leftop+fdwidth] = finderpattern
    end
    @test all(mat[leftop:leftop+fdwidth] == stdmat[leftop:leftop+fdwidth] for leftop in fdpos)

    # seperators
    sepinds = getsepinds(code)
    mat[sepinds] .= false
    @test mat[sepinds] == stdmat[sepinds]

    # timing series
    tinds = gettiminginds(code)
    half = length(tinds) >> 1
    mat[tinds[1:half]] = mat[tinds[half+1:end]] = push!(repeat([false, true], half÷2), false)
    @test mat[tinds] == stdmat[tinds]

    # dark mode
    mat[getdarkindex(code)] = true
    @test mat[getdarkindex(code)] == stdmat[getdarkindex(code)]

    # alignment pattern
    algpos = getalignmentinds(code)
    algwidth = CartesianIndex(4, 4)
    for leftop in algpos
        mat[leftop:leftop+algwidth] = alignmentpattern
    end
    @test all(mat[leftop:leftop+algwidth] == stdmat[leftop:leftop+algwidth] for leftop in algpos)

    # version
    vinds = getversioninds(code)
    mat[vinds] = repeat(qrversionbits(code), 2)
    @test mat[vinds] == stdmat[vinds]
    # Gray.(.! mat)

    # format
    finds = getformatinds(code)
    mat[finds] = repeat(qrformat(code), 2)
    @test mat[finds] == stdmat[finds]

    # data bits
    databits = encodemessage(code)
    datainds = getindexes(code)
    mat[datainds] = databits

    # apply mask
    maskmat = makemask(code)
    mat .⊻= maskmat
    @test mat[datainds] == stdmat[datainds]

    # decode
    info = qrdecode(mat)
    @test info.message == code.message &&
          info.eclevel == code.eclevel &&
          info.version == code.version &&
          info.mask == code.mask
end