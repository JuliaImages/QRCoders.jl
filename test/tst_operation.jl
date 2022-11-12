# Test for polynomials and GF(256) integers

## Euclidean division of polynomials
@testset "Euclidean division" begin
    ## original method of `geterrcode`
    tail!(p::Poly)::Poly = Poly(deleteat!(p.coeff, 1))
    init!(p::Poly)::Poly = Poly(deleteat!(p.coeff, length(p)))
    function geterrorcorrection(a::Poly, n::Int)::Poly
        la = length(a)
        a = a << n
        g = generator(n) << la
    
        for _ in 1:la
            tail!(g)
            a = init!(last(a.coeff) * g + a)
        end
        return a
    end
    ### message polynomial f(x)
    fdeg, n = rand(1:155), rand(1:100)
    f = randpoly(fdeg)
    err = geterrcode(f, n) ## error correction code
    rem = geterrorcorrection(f, n) ## remainder of Euclidean division
    @test rem == err

    ## systematic decoding
    fdeg, n = rand(1:155), rand(1:100)
    rawmsg = randpoly(fdeg)
    msg = rawmsg << n + geterrcode(f, n)
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
    f, g = randpoly(1:255), Poly([rand(0x1:0xff)])
    q, r = f ÷ g, f % g
    @test iszeropoly(f + g * q + r)
    ### g(x) = x
    f, g = randpoly(2:255), Poly(UInt8[0, 1, 0, 0])
    q, r = f ÷ g, f % g
    @test q == Poly(f.coeff[2:end]) && r == Poly([first(f.coeff)])
    ### divide zero
    @test_throws DivideError randpoly(Int, 1:255) ÷ Poly([0, 0, 0])
    @test_throws DivideError randpoly(Int, 1:255) % Poly([0, 0])
    @test_throws DivideError euclidean_divide(randpoly(1:255), Poly(UInt8[0]))
end

@testset "Basic operations" begin
    ## mult and divide
    a, b = rand(0:255), rand(1:255)
    c = divide(a, b)
    @test mult(b, c) == mult(c, b) == a

    ## divide, gfpow2, gflog2, gfinv
    @test gfpow2.(0:255) == gfpow2.(0x0:0xff)
    ap, bp, cp = [rand(1:255) for _ in 1:3]
    a, b, c = gfpow2.([ap, bp, cp])
    @test mult(divide(a, b), c) == gfpow2(ap - bp + cp)
    @test divide(0, rand(1:255)) == 0
    @test_throws DivideError divide(rand(1:255), 0)
    @test_throws BoundsError gflog2(-1)
    @test_throws BoundsError gflog2(0)
    @test all(1 == mult(i, gfinv(i)) for i in 1:255)
    @test_throws BoundsError gfinv(0)

    ## log table
    @test sort(powtable) == 1:255
    
    ## copy
    p1 = Poly([1, 2, 3])
    p2 = copy(p1)
    p2.coeff[1] = 3
    @test p2 != p1
    
    ## zeros, unit, rstripzeros, rpadzeros
    @test zero(Poly{Int}) == Poly([0])
    @test zero(Poly{UInt8}) == Poly{UInt8}([0]) == Poly([0x0])
    @test rstripzeros(Poly([1, 0, 2, 0, 0])) == Poly([1, 0, 2])
    @test rstripzeros(Poly([0, 0, 0, 0, 0])) == Poly([0])
    @test rpadzeros(Poly([1, 0, 2]), 5) == Poly([1, 0, 2, 0, 0])
    @test rpadzeros(Poly([1, 0, 2]), 3) == Poly([1, 0, 2])
    @test_throws String rpadzeros(Poly([1, 0, 2]), 2)
    f = randpoly(Int, 1:255)
    @test f * unit(Poly{Int}) == f == unit(Poly{Int}) * f
    @test unit(Poly{Int}) == Poly([1])

    ## degree
    @test degree(Poly([1, 0, 2, 0, 0])) == 2
    @test degree(Poly([0, 0, 0, 0, 0])) == degree(Poly([0])) == -1
    @test degree(Poly([3])) == 0

    ## type convert: bitarray <-> int
    @test all(i == (bitarray2int ∘ int2bitarray)(i) for i in 0:2^8-1)

    ## alphanumeric, antialphanumeric
    @test all(alphanumeric[antialphanumeric[i]] == i for i in 0:44)
    @test all(antialphanumeric[alphanumeric[i]] == i for i in keys(alphanumeric))
    ## kanji, antikanji
    @test all(kanji[antikanji[i]] == i for i in keys(antikanji))
    @test all(antikanji[kanji[i]] == i for i in keys(kanji))

    ## modes
    @test Numeric() ⊆ Alphanumeric() ⊆ Byte() ⊆ UTF8()
    @test Kanji() ⊆ UTF8() && !(Kanji() ⊆ Byte())
    @test !(Numeric() ⊆ Kanji())
    @test !(Alphanumeric() ⊆ Numeric())

    ## eltype
    @test eltype(collect(randpoly(Int, 13))) == Int
    @test eltype(collect(randpoly(UInt8, 13))) == UInt8
end

@testset "Tests for polynomials and error encoding" begin
    @test 2 * Poly([1,2]) == Poly([2,4]) == Poly([1,2]) * 2
    @test 0x2 * Poly(UInt8[1,2]) == Poly(UInt8[2,4]) == Poly(UInt8[1,2]) * 0x2
    
    function oriprod(a::Poly, b::Poly)::Poly
        return sum([ c * (a << (p - 1)) for (p, c) in enumerate(b.coeff)])
    end
    a, b = randpoly(1:255), randpoly(1:255)
    @test a * b == oriprod(a, b)
    
    @test all(i == antipowtable[powtable[i+1]] for i in 0:254)
    @test all(i == powtable[antipowtable[i]+1] for i in 1:255)

    p = Poly(rand(UInt8, 10))
    q = Poly(rand(UInt8, 20))
    @test Poly(UInt8[1]) * p == p
    @test p * q == q * p
    @test p + q == q + p

    @test p + p == Poly(zeros(UInt8, 10))

    @test Poly([1, 1]) * Poly([2, 1]) == Poly([2, 3, 1])
    @test Poly([1, 1]) * Poly([2, 1]) * Poly([4, 1]) == Poly([8, 14, 7, 1])
    a, p = rand(UInt8), randpoly(UInt8, 1:255)
    @test Poly([a]) * p == a * p

    @test generator(Int, 2) == Poly([2, 3, 1])
    @test generator(Int, 3) == Poly([8, 14, 7, 1])
    @test generator(UInt8, 2) == Poly{UInt8}([2, 3, 1])
    @test generator(3) == Poly(UInt8[8, 14, 7, 1])

    g7 = [21, 102, 238, 149, 146, 229, 87, 0]
    @test generator(7) == Poly(map(n -> powtable[n+1], g7))

    g8 = [28, 196, 252, 215, 249, 208, 238, 175, 0]
    @test generator(8) == Poly(map(n -> powtable[n+1], g8))

    g9 = [36, 123, 11, 149, 235, 231, 137, 246, 95, 0]
    @test generator(9) == Poly(map(n -> powtable[n+1], g9))

    g12 = [66, 157, 87, 131, 143, 198, 113, 187, 121, 98, 43, 102, 0]
    @test generator(12) == Poly(map(n -> powtable[n+1], g12))

    msg = [17, 236, 17, 236, 17, 236, 64, 67, 77, 220, 114, 209, 120, 11, 91, 32]
    r = [23, 93, 226, 231, 215, 235, 119, 39, 35, 196]
    @test geterrcode(Poly(msg), 10) == Poly(r)

    msg = [70,247,118,86,194,6,151,50,16,236,17,236,17,236,17,236]
    r = [235, 159, 5, 173, 24, 147, 59, 33, 106, 40, 255, 172, 82, 2,
         131, 32, 178, 236]
    @test geterrcode(Poly(reverse(msg)), 18) == Poly(reverse(r))
end

@testset "Generator matrix" begin
    # test for multiplication
    A, B, C = rand(0:255, 4, 4), rand(0:255, 4, 4), rand(0:255, 4, 4)
    b = rand(0:255, 4)
    @test mult(A, mult(B, C)) == mult(mult(A, B), C)
    @test mult(A, mult(B, b)) == mult(mult(A, B), b)

    encode(f::Poly, n::Int) = (f << n) + (f << n) % generator(n)
    G = generator_matrix(3, 4)
    f = randpoly(3)
    @test mult(G, f.coeff) == encode(f, 4).coeff

    m = rand(1:254)
    n = rand(1:255-m)
    G = generator_matrix(m, n)
    @test size(G) == (m+n, m)
    f = randpoly(m)
    @test mult(G, f.coeff) == encode(f, n).coeff

    @test powx(Int, 2) == Poly([0, 0, 1])
    @test powx(0) == Poly{UInt8}([1])
    @test powx(1, 3) == Poly{UInt8}([0, 1, 0])
    @test_throws DomainError powx(3, 3)
end