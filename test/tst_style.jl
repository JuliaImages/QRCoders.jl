# Test for style of QR code
@testset "unicode plot" begin
    alphabets = [join('0':'9'), keys(alphanumeric), join(Char.(0:255)), keys(kanji)]
    for alphabet in alphabets
        msg = join(rand(alphabet, 100))
        canvas = unicodeplot(msg)
    end
    @test true
end