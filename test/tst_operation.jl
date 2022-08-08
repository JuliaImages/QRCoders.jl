# Test for polynomials and GF(256) integers

## Euclidean division of polynomials
@testset "Euclidean division" begin
    ## use Euclidean operator to obtain `geterrorcorrection`
    geterrcode(f::Poly, n::Int) = f << n % generator(n)
    ### message polynomial f(x) with degree ≤ 31
    fdeg, n = rand(1:31), rand(1:10)
    f = Poly([rand(1:255) for _ in 1:(fdeg+1)])
    err = geterrorcorrection(f, n) ## error correction code
    rem = geterrcode(f, n) ## remainder of Euclidean division
    @test rem == err

    ## operator ÷, %, *
    f = Poly([rand(0:255, 15)..., rand(1:255)]) # f(x) with degree == 15
    g = Poly([rand(0:255, 7)..., rand(1:255)]) # g(x) with degree == 7
    q, r = f ÷ g, f % g # remainder
    @test all(iszero, (f + g * q + r).coeff)
end

## Euclidean division of GF256 integers
@testset "GF(256) division" begin
    ## mult and divide
    a, b = rand(0:255), rand(1:255)
    c = divide(a, b)
    @test mult(b, c) == mult(c, b) == a

    ## divide and antilogtable
    ap, bp, cp = [rand(1:255) for _ in 1:3]
    a, b, c = getindex.(Ref(logtable), [ap, bp, cp])
    @test mult(divide(a, b), c) == logtable[mod(ap - bp + cp, 255)]
end