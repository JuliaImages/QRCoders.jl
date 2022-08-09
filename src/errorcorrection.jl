module Polynomial

export Poly, geterrorcorrection

"""
Data structure to encode polynomials to generate the error correction codewords.
"""
struct Poly
    coeff::Vector{Int}
end

"""
    makelogtable()

Retrun a list of logarithm values for the Galois Field GF(256).
"""
function makelogtable()
    t = ones(Int, 256)
    v = 1
    for i in 2:256
        v = 2 * v
        if v > 255
            v = xor(v, 285) # According to the specs
        end
        t[i] = v
    end
    return t
end

"""
Logarithm table for GF(256).
"""
const logtable = Dict{Int, Int}(zip(0:255, makelogtable()))

"""
Anti-logarithm table for GF(256).
"""
const antilogtable = Dict{Int, Int}(zip(makelogtable(), 0:254))

"""
    gfpow2(n::Int)

Returns 2^n in GF256.
"""
gfpow2(n::Int) = logtable[mod(n, 255)]

"""
    gflog2(n::Int)

Returns the logarithm of n to base 2 in GF256.
"""
function gflog2(n::Int)
    1 ≤ n ≤ 255 || throw(DomainError("gflog2: n must be between 1 and 255"))
    return antilogtable[n]
end

"""
    function mult(a::Int, b::Int)

Multiplies two integers in GF(256).
"""
function mult(a::Int, b::Int)::Int
    (a == 0 || b == 0) && return 0
    return gfpow2(gflog2(a) + gflog2(b))
end

"""
    divide(a::Int, b::Int)

Division of intergers in GF(256).
"""
function divide(a::Int, b::Int)
    b == 0 && throw(DivideError())
    b == 1 && return a ## frequently used when dealing with generator polynomial
    return gfpow2(gflog2(a) - gflog2(b))
end

import Base: length, iterate, ==, <<, +, *, ÷, %

"""
    length(p::Poly)

Return the degree of the polynomial.
"""
length(p::Poly) = length(p.coeff)

iterate(p::Poly) = iterate(p.coeff)
iterate(p::Poly, i) = iterate(p.coeff, i)

==(a::Poly, b::Poly)::Bool = a.coeff == b.coeff

"""
    <<(p::Poly, n::Int)

Increase the degree of `p` by `n`.
"""
<<(p::Poly, n::Int)::Poly = Poly(vcat(zeros(n), p.coeff))

+(p::Poly) = p

function +(a::Poly, b::Poly)::Poly
    l = max(length(a), length(b))
    return Poly([xor(get(a.coeff, i, 0), get(b.coeff, i, 0)) for i in 1:l])
end

*(a::Int, p::Poly)::Poly = Poly(map(x->mult(a, x), p.coeff))

function *(a::Poly, b::Poly)::Poly
    return sum([ c * (a << (p - 1)) for (p, c) in enumerate(b.coeff)])
end

"""
    ÷(f::Poly, g::Poly)

Quotient of Euclidean division.
"""
function ÷(f::Poly, g::Poly)
    quodeg = length(f) - length(g) ## degree of the quotient polynomial
    quodeg < 0 && return Poly([0])
    g <<= quodeg
    gn = lead(g) ## leading term of g(x)
    quocoef = Vector{Int}(undef, quodeg + 1)
    for i in 1:quodeg
        quocoef[i] = divide(lead(f), gn)
        f = init!(quocoef[i] * g + f)
        tail!(g)
    end
    quocoef[end] = divide(lead(f), gn)
    return Poly(reverse!(quocoef))
end

"""
    %(f::Poly, g::Poly)

Remainder of Euclidean division.
"""
function %(f::Poly, g::Poly)
    quodeg = length(f) - length(g) ## degree of the quotient polynomial
    quodeg < 0 && return f
    g <<= quodeg
    gn = lead(g) ## leading term of g(x)
    for _ in 1:quodeg
        f = init!(divide(lead(f), gn) * g + f)
        tail!(g)
    end
    return init!(divide(lead(f), gn) * g + f)
end

"""
    generator(n::Int)

Create the Generator Polynomial of degree `n`.
"""
function generator(n::Int)::Poly
    prod([Poly([gfpow2(i - 1), 1]) for i in 1:n])
end

"""
    lead(p::Poly)

Return the leading coefficient of `p`.
"""
lead(p::Poly) = last(p.coeff)

"""
    init!(p::Poly)

Delete the leading coefficient of `p`.
"""
init!(p::Poly)::Poly = Poly(deleteat!(p.coeff, length(p)))

"""
    tail!(p::Poly)

Decrease the degree of `p` by one.
"""
tail!(p::Poly)::Poly = Poly(deleteat!(p.coeff, 1))

"""
    geterrorcorrection(a::Poly, n::Int)

Return a polynomial containing the `n` error correction codewords of `a`.
"""
function geterrorcorrection(a::Poly, n::Int)::Poly
    la = length(a)
    a = a << n
    g = generator(n) << la

    for _ in 1:la
        tail!(g)
        a = init!(lead(a) * g + a)
    end
    return a
end

end # module
