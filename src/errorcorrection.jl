module Polynomial

export Poly, geterrorcorrection

struct Poly
    coeff::Array{Int64,1}
end

function makelogtable()::Array{Int64}
    t = ones(Int64, 256)
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

const logtable = Dict{Int64, Int64}(zip(0:255, makelogtable()))

const antilogtable = Dict{Int64, Int64}(zip(makelogtable(), 0:254))

function mult(a::Int64, b::Int64)::Int64
    if a == 0 || b == 0
        return 0
    end
    xa = antilogtable[a]
    xb = antilogtable[b]
    return logtable[(xa + xb) % 255]
end

import Base: length, iterate, ==, <<, +, *

length(p::Poly)::Int64 = length(p.coeff)

iterate(p::Poly) = iterate(p.coeff)
iterate(p::Poly, i) = iterate(p.coeff, i)

==(a::Poly, b::Poly)::Bool = a.coeff == b.coeff

<<(p::Poly, n::Int64)::Poly = Poly(vcat(zeros(n), p.coeff))

+(p::Poly) = p

function +(a::Poly, b::Poly)::Poly
    l = max(length(a), length(b))
    return Poly([xor(get(a.coeff, i, 0), get(b.coeff, i, 0)) for i in 1:l])
end

*(a::Int64, p::Poly)::Poly = Poly(map(x->mult(a, x), p.coeff))

function *(a::Poly, b::Poly)::Poly
    return sum([ c * (a << (p - 1)) for (p, c) in enumerate(b.coeff)])
end

function generator(n::Int64)::Poly
    prod([Poly([logtable[i - 1], 1]) for i in 1:n])
end

lead(p::Poly)::Int64 = last(p.coeff)
init!(p::Poly)::Poly = Poly(deleteat!(p.coeff, length(p)))
tail!(p::Poly)::Poly = Poly(deleteat!(p.coeff, 1))

function geterrorcorrection(a::Poly, n::Int64)::Poly
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
