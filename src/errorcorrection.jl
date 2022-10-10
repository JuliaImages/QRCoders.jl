module Polynomial

export Poly, geterrorcorrection

import Base: length, iterate, ==, <<, +, *, ÷, %, copy, zero

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
        v <<= 1
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

Returns 2^n in GF(256).
"""
gfpow2(n::Int) = logtable[mod(n, 255)]

"""
    gflog2(n::Integer)

Returns the logarithm of n to base 2 in GF(256).
"""
function gflog2(n::Integer)
    1 ≤ n ≤ 255 || throw(DomainError("gflog2: $n must be between 1 and 255"))
    return antilogtable[n]
end

"""
Multiplication table of non-zero elements in GF(256).
"""
const multtable = [i*j == 0 ? 0 : gfpow2(gflog2(i) + gflog2(j)) for i in 0:255, j in 0:255]


"""
Division table of non-zero elements in GF(256).
"""
const divtable = [i == 0 ? 0 : gfpow2(gflog2(i) - gflog2(j)) for i in 0:255, j in 1:255]

"""
    mult(a::Integer, b::Integer)

Multiplies two integers in GF(256).
"""
function mult(a::Integer, b::Integer)
    # (a == 0 || b == 0) && return 0
    # gfpow2(gflog2(a) - gflog2(b))
    return multtable[a + 1, b + 1]
end

"""
    divide(a::Integer, b::Integer)

Division of intergers in GF(256).
"""
function divide(a::Integer, b::Integer)
    b == 0 && throw(DivideError())
    return divtable[a + 1, b]
end

"""
    gfinv(a::Integer)
"""
gfinv(a::Integer) = gfpow2(-gflog2(a))

"""
    iszeropoly(p::Poly)

Returns true if p is a zero polynomial.
"""
iszeropoly(p::Poly) = all(iszero, p)

"""
    rstripzeros(p::Poly)

Remove trailing zeros from polynomial p.
"""
rstripzeros(p::Poly) = rstripzeros!(copy(p))
function rstripzeros!(p::Poly)
    iszeropoly(p) && return zero(Poly)
    deleteat!(p.coeff, findlast(!iszero, p.coeff) + 1:length(p))
    return p
end

"""
    rpadzeros(p::Poly, n::Int)

Add zeros to the right side of p(x) such that length(p) == n.
"""
rpadzeros(p::Poly, n::Int) = rpadzeros!(copy(p), n)
function rpadzeros!(p::Poly, n::Int)
    length(p) > n && throw("rpadzeros: length(p) > n")
    append!(p.coeff, zeros(Int, n - length(p)))
    return p
end

"""
    degree(p::Poly)

Returns the degree of polynomial p.
"""
function degree(p::Poly)
    iszeropoly(p) && return -1
    return findlast(!iszero, p.coeff) - 1
end

"""
    zero(::Type)

Returns the zero polynomial.
"""
zero(::Type{Poly})= Poly(zeros(Int, 1))

"""
    unit(::Type)

Returns the unit polynomial.
"""
unit(::Type{Poly}) = Poly(ones(Int, 1))

"""
    copy(p::Poly)

Create a copy of polynomial p.
"""
copy(p::Poly) = Poly(copy(p.coeff))

"""
    length(p::Poly)

Return the degree of the polynomial.
"""
length(p::Poly) = length(p.coeff)

iterate(p::Poly) = iterate(p.coeff)
iterate(p::Poly, i) = iterate(p.coeff, i)

==(a::Poly, b::Poly)::Bool = iszeropoly(a + b)

"""
    <<(p::Poly, n::Int)

Increase the degree of `p` by `n`.
"""
<<(p::Poly, n::Int)::Poly = Poly(vcat(zeros(Int, n), p.coeff))

function +(a::Poly, b::Poly)::Poly
    l = max(length(a), length(b))
    return Poly([xor(get(a.coeff, i, 0), get(b.coeff, i, 0)) for i in 1:l])
end

*(a::Integer, p::Poly)::Poly = Poly(map(x->mult(a, x), p.coeff))
function *(a::Poly, b::Poly)::Poly
    prodpoly = Poly(zeros(Int, length(a) + length(b) - 1))
    for (i, c1) in enumerate(a.coeff), (j, c2) in enumerate(b.coeff)
        @inbounds prodpoly.coeff[i + j - 1] ⊻= mult(c2, c1) # column first
    end
    return prodpoly
end

"""
    euclidean_divide(f::Poly, g::Poly)

Returns the quotient and the remainder of Euclidean division.
"""
euclidean_divide(f::Poly, g::Poly) = euclidean_divide!(copy(f), copy(g))

"""
    euclidean_divide!(f::Poly, g::Poly)

Implement of Euclidean division with minimized allocations.
"""
function euclidean_divide!(f::Poly, g::Poly)
    ## remove trailing zeros
    g, f = rstripzeros!(g), rstripzeros!(f)
    iszeropoly(g) && throw(DivideError())
    fcoef, gcoef, lf, lg = f.coeff, g.coeff, length(f), length(g)
    ## leading term of g(x)
    gn = last(gcoef)
    ## g(x) is a constant
    if lg == 1
        fcoef .= divide.(fcoef, gn)
        return f, zero(Poly)
    end
    ## degree of the quotient polynomial
    quodeg = lf - lg
    ## deg(f) < deg(g)
    quodeg < 0 && return zero(Poly), f
    ## remainder and quotient polynomial
    @inbounds for i in 0:quodeg
        leadterm = divide(fcoef[end-i], gn)
        for (j, c) in enumerate(gcoef)
            fcoef[quodeg - i + j] ⊻= mult(leadterm, c)
        end
        fcoef[end-i] = leadterm
    end
    quo = Poly(fcoef[end-quodeg:end]) # here @view will be a little bit slower
    deleteat!(fcoef, lf-quodeg:lf)
    return quo, f
end

"""
    ÷(f::Poly, g::Poly)

Quotient of Euclidean division.
"""
÷(f::Poly, g::Poly) = first(euclidean_divide(f, g))

"""
    %(f::Poly, g::Poly)

Remainder of Euclidean division.
"""
%(f::Poly, g::Poly) = last(euclidean_divide(f, g))

"""
    generator(n::Int)

Create the Generator Polynomial of degree `n`.
"""
generator(n::Int) = prod([Poly([gfpow2(i - 1), 1]) for i in 1:n])

"""
    geterrorcorrection(f::Poly, n::Int)

Return a polynomial containing the `n` error correction codewords of `f`.
"""
geterrorcorrection(f::Poly, n::Int) = rpadzeros!(f << n % generator(n), n)
end # module
