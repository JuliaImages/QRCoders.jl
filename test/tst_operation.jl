# Test for polynomials and GF(256) integers

## Euclidean division of polynomials
@testset "Euclidean division" begin
    ## use Euclidean operator to obtain `geterrorcorrection`
    geterrcode(f::Poly, n::Int) = rpadzeros(f << n % generator(n), n)
    ### message polynomial f(x)
    fdeg, n = rand(1:155), rand(1:100)
    f = randpoly(fdeg)
    err = geterrorcorrection(f, n) ## error correction code
    rem = geterrcode(f, n) ## remainder of Euclidean division
    @test rem == err

    ## systematic decoding
    fdeg, n = rand(1:155), rand(1:100)
    rawmsg = randpoly(fdeg)
    msg = rawmsg << n + geterrorcorrection(f, n)
    @test msg.coeff[(n + 1):end] == rawmsg.coeff

    ## operator ÷, %, *
    ### leading term != 0
    f, g = randpoly(1:255), randpoly(1:255)
    q, r = f ÷ g, f % g # remainder
    @test iszeropoly(f + g * q + r)
    ### leading term allowed to be 0
    f, g = Poly(rand(0:255, rand(1:255))), Poly(rand(0:255, rand(1:255)))
    q, r = f ÷ g, f % g
    @test iszeropoly(f + g * q + r)
    ### g is a constant
    f, g = randpoly(1:255), Poly([rand(1:255)])
    q, r = f ÷ g, f % g
    @test iszeropoly(f + g * q + r)
    ### g(x) = x
    f, g = randpoly(1:255), Poly([0, 1, 0, 0])
    q, r = f ÷ g, f % g
    @test q == Poly(f.coeff[2:end]) && r == Poly([first(f.coeff)])
    ### divide zero
    @test_throws DivideError randpoly(1:255) ÷ Poly([0, 0, 0])
    @test_throws DivideError randpoly(1:255) % Poly([0, 0])
    @test_throws DivideError euclidean_divide(randpoly(1:255), Poly([0]))
end

@testset "Basic operations" begin
    ## mult and divide
    a, b = rand(0:255), rand(1:255)
    c = divide(a, b)
    @test mult(b, c) == mult(c, b) == a

    ## divide, gfpow2, gflog2, gfinv
    ap, bp, cp = [rand(1:255) for _ in 1:3]
    a, b, c = gfpow2.([ap, bp, cp])
    @test mult(divide(a, b), c) == gfpow2(ap - bp + cp)
    @test divide(0, rand(1:255)) == 0
    @test_throws DivideError divide(rand(1:255), 0)
    @test_throws DomainError gflog2(-1)
    @test_throws DomainError gflog2(0)
    @test all(1 == mult(i, gfinv(i)) for i in 1:255)
    @test_throws DomainError gfinv(0)
    
    ## copy
    p1 = Poly([1, 2, 3])
    p2 = copy(p1)
    p2.coeff[1] = 3
    @test p2 != p1
    
    ## zeros, unit
    @test zero(Poly) == Poly([0])
    @test rstripzeros(Poly([1, 0, 2, 0, 0])) == Poly([1, 0, 2])
    @test rstripzeros(Poly([0, 0, 0, 0, 0])) == Poly([0])
    f = randpoly(1:255)
    @test f * unit(Poly) == f == unit(Poly) * f
    @test unit(Poly) == Poly([1])

    ## degree
    @test degree(Poly([1, 0, 2, 0, 0])) == 2
    @test degree(Poly([0, 0, 0, 0, 0])) == degree(Poly([0])) == -1
    @test degree(Poly([3])) == 0
end