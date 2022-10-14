module Polynomial

export Poly, geterrcode

import Base: length, iterate, ==, <<, +, *, ÷, %, copy, zero, eltype

"""
Data structure to encode polynomials to generate the error correction codewords.
"""
struct Poly{T<:Integer}
    coeff::Vector{T}
end

"""
Values of 2⁰, 2¹,..., 2²⁵⁴ in Galois Field GF(256).

Note that 2²⁵⁵ = 1, so we don't need to store it.
"""
const powtable = let
    table = ones(UInt8, 255)
    v = 1
    for i in 2:255
        v <<= 1
        if v > 255
            v = xor(v, 285) # According to the specs
        end
        table[i] = v
    end
    table
end

"""
Values of log₂1, log₂2, ..., log₂255 in GF(256).

Note that it is a table of `Int64`s instead of `UInt8`s.
"""
const antipowtable = let
    table = Vector{Int}(undef, 255)
    table[powtable] .= 0:254
    table
end

"""
    gfpow2(n::Int)

Returns 2ⁿ in GF(256).
"""
gfpow2(n::Integer) = powtable[mod(n, 255) + 1]

"""
    gflog2(n::Integer)

Returns the logarithm of n to base 2 in GF(256).
"""
gflog2(n::Integer) = antipowtable[n]

"""
Multiplication table of non-zero elements in GF(256).
"""
const multtable = [iszero(i * j) ? 0x0 : gfpow2(gflog2(i) + gflog2(j)) for i in 0:255, j in 0:255]


"""
Division table of non-zero elements in GF(256).
"""
const divtable = [iszero(i) ? 0x0 : gfpow2(gflog2(i) - gflog2(j)) for i in 0:255, j in 1:255]

"""
    mult(a::Integer, b::Integer)

Multiplies two integers in GF(256).
"""
function mult(a::Integer, b::Integer)
    # same as gfpow2(gflog2(a) + gflog2(b))
    return multtable[a + 1, b + 1]
end

"""
    divide(a::Integer, b::Integer)

Division of intergers in GF(256).
"""
function divide(a::Integer, b::Integer)
    iszero(b) && throw(DivideError())
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
function rstripzeros!(p::Poly{T}) where T
    iszeropoly(p) && return zero(Poly{T})
    deleteat!(p.coeff, findlast(!iszero, p.coeff) + 1:length(p))
    return p
end

"""
    rpadzeros(p::Poly, n::Int)

Add zeros to the right side of p(x) such that length(p) == n.
"""
rpadzeros(p::Poly, n::Int) = rpadzeros!(copy(p), n)
function rpadzeros!(p::Poly{T}, n::Int) where T
    length(p) > n && throw("rpadzeros: length(p) > n")
    append!(p.coeff, zeros(T, n - length(p)))
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
zero(::Type{Poly{T}}) where T = Poly{T}(zeros(T, 1))

"""
    unit(::Type)

Returns the unit polynomial.
"""
unit(::Type{Poly{T}}) where T = Poly{T}(ones(T, 1))

"""
    copy(p::Poly)

Create a copy of polynomial p.
"""
copy(p::Poly{T}) where T = Poly{T}(copy(p.coeff))

"""
    length(p::Poly)

Return the degree of the polynomial.
"""
length(p::Poly) = length(p.coeff)

## used for iteration
iterate(p::Poly) = iterate(p.coeff)
iterate(p::Poly, i) = iterate(p.coeff, i)
eltype(::Poly{T}) where T = T

==(a::Poly, b::Poly)::Bool = iszeropoly(a + b)

"""
    <<(p::Poly, n::Int)

Increase the degree of `p` by `n`.
"""
<<(p::Poly{T}, n::Int) where T = Poly{T}(vcat(zeros(T, n), p.coeff))

function +(a::Poly{T}, b::Poly{T}) where T
    l = max(length(a), length(b))
    return Poly{T}([xor(get(a.coeff, i, zero(T)), get(b.coeff, i, zero(T))) for i in 1:l])
end

"""
    *(p, q)

Multiply two polynomials or a polynomial with a scalar.
"""
*(a::T, p::Poly{T}) where T = Poly{T}(mult.(a, p.coeff))
*(p::Poly{T}, a::T) where T = Poly{T}(mult.(a, p.coeff))
function *(a::Poly{T}, b::Poly{T}) where T
    prodpoly = Poly(zeros(T, length(a) + length(b) - 1))
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
function euclidean_divide!(f::Poly{T}, g::Poly{T}) where T
    ## remove trailing zeros
    g, f = rstripzeros!(g), rstripzeros!(f)
    iszeropoly(g) && throw(DivideError())
    fcoef, gcoef, lf, lg = f.coeff, g.coeff, length(f), length(g)
    ## leading term of g(x)
    gn = last(gcoef)
    ## g(x) is a constant
    if isone(lg)
        fcoef .= divide.(fcoef, gn)
        return f, zero(Poly{T})
    end
    ## degree of the quotient polynomial
    quodeg = lf - lg
    ## deg(f) < deg(g)
    quodeg < 0 && return zero(Poly{T}), f
    ## remainder and quotient polynomial
    @inbounds for i in 0:quodeg
        leadterm = divide(fcoef[end-i], gn)
        for (j, c) in enumerate(gcoef)
            fcoef[quodeg - i + j] ⊻= mult(leadterm, c)
        end
        fcoef[end-i] = leadterm
    end
    quo = Poly{T}(fcoef[end-quodeg:end]) # here @view will be a little bit slower
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
generator(n::Int) = generator(UInt8, n)
generator(::Type{T}, n::Int) where T = prod([Poly{T}([powtable[i], one(T)]) for i in 1:n])


"""
    geterrcode(f::Poly, n::Int)

Return a polynomial containing the `n` error correction codewords of `f`.
"""
geterrcode(f::Poly{T}, n::Int) where T = rpadzeros!(f << n % generator(T, n), n)
end # module
