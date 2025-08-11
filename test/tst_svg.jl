@testset "exportsvg" begin
    msg = "SVG test"
    svgstr = exportsvg(msg)
    @test startswith(svgstr, "<svg")
    @test occursin("fill=\"#000\"", svgstr) || occursin("fill=\"black\"", svgstr)
    @test occursin("fill=\"#fff\"", svgstr) || occursin("fill=\"white\"", svgstr)

    # File output
    tmp = mktempdir()
    fpath = joinpath(tmp, "testqr.svg")
    svgstr2 = exportsvg("Another QR"; path=fpath)
    @test isfile(fpath)
    @test startswith(read(fpath, String), "<svg")
    @test length(svgstr2) > 100
    @test length(read(fpath, String)) == length(svgstr2)

    # Unicode
    s_uni = exportsvg("你好世界")
    @test startswith(s_uni, "<svg")

    # Distinct strings for distinct messages
    svg1 = exportsvg("aaa")
    svg2 = exportsvg("bbb")
    @test svg1 != svg2

    # Sizing
    codebig = exportsvg("big", size=600)
    found = match(r"width=\"(\d+)\"", codebig)
    @test found !== nothing
    w = parse(Int, found.captures[1])
    @test w > 0 && w ≤ 600

    # Custom colors
    svgcol = exportsvg("col"; darkcolor="navy", lightcolor="#ffb")
    @test occursin("fill=\"#ffb\"", svgcol) || occursin("fill=\"#FFB\"", svgcol)
    @test occursin("fill=\"navy\"", svgcol)

    # matrix2svg
    mat = qrcode("matrix2svg test")
    svgmat = matrix2svg(mat; size=140, darkcolor="#111", lightcolor="#eee")
    @test startswith(svgmat, "<svg")
    @test occursin("fill=\"#111\"", svgmat)
    @test occursin("fill=\"#eee\"", svgmat)
    matfile = joinpath(tmp, "matrixqr.svg")
    svgmatfile = matrix2svg(mat, path=matfile)
    @test isfile(matfile)
    @test read(matfile, String) == svgmatfile

    # Optional: Check for no errors with size=0, or provide your own error
    # @test_throws SomeException exportsvg("bad", size=0)
    # @test_throws SomeException matrix2svg(mat; size=0)
end

@testset "SVG roundtrip decode (exportsvg)" begin
    if Sys.which("rsvg-convert") !== nothing && Sys.which("zbarimg") !== nothing
        msg = "Automated roundtrip exportsvg"
        svg = exportsvg(msg)
        svgfile = tempname() * ".svg"
        pngfile = tempname() * ".png"
        open(svgfile, "w") do f; write(f, svg); end
        run(`rsvg-convert $svgfile -o $pngfile`)
        output = read(`zbarimg --quiet --raw $pngfile`, String)
        @test strip(output) == msg
    else
        @info "Skipping exportsvg roundtrip decode: tools missing."
    end
end

@testset "SVG roundtrip decode (matrix2svg)" begin
    if Sys.which("rsvg-convert") !== nothing && Sys.which("zbarimg") !== nothing
        msg = "Automated roundtrip matrix2svg"
        mat = qrcode(msg)
        svg = matrix2svg(mat)
        svgfile = tempname() * ".svg"
        pngfile = tempname() * ".png"
        open(svgfile, "w") do f; write(f, svg); end
        run(`rsvg-convert $svgfile -o $pngfile`)
        output = read(`zbarimg --quiet --raw $pngfile`, String)
        @test strip(output) == msg
    else
        @info "Skipping matrix2svg roundtrip decode: tools missing."
    end
end