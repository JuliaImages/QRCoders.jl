module Polynomial

export Poly, logtable, antilogtable, generator, mult, geterrorcorrection

struct Poly
    coeff::Array{Int,1}
end

const modulo = 285

function makelogtable()
    t = ones(Int, 256)
    v = 1
    for i in 2:256
        v = 2 * v
        if v > 255
            v = xor(v, modulo)
        end
        t[i] = v
    end
    return t
end

const logtable = Dict{Int,Int}(zip(0:255, makelogtable()))

const antilogtable = Dict{Int,Int}(zip(makelogtable(), 0:254))

function mult(a::Int, b::Int)
    if a == 0 || b == 0
        return 0
    end
    xa = antilogtable[a]
    xb = antilogtable[b]
    return logtable[(xa + xb) % 255]
end

function divi(a::Int, b::Int)
    if a == 0 || b == 0
        return 0
    end
    xa = antilogtable[a]
    xb = antilogtable[b]
    return logtable[mod(xa - xb, 255)]
end


import Base: length, +, *, divrem, iterate, vcat, ==

==(a::Poly, b::Poly) = a.coeff == b.coeff

length(p::Poly) = length(p.coeff)

+(p::Poly) = p

function +(a::Poly, b::Poly)
    l = max(length(a), length(b))
    return Poly([xor(get(a.coeff, i, 0), get(b.coeff, i, 0)) for i in 1:l])
end

*(a::Int, p::Poly) = Poly(map(x->mult(a, x), p.coeff))

iterate(p::Poly) = iterate(p.coeff)
iterate(p::Poly, i) = iterate(p.coeff, i)

vcat(p::Poly, a::Array{Float64,1}) = Poly(vcat(p.coeff, a))
vcat(a::Array{Float64,1}, p::Poly) = Poly(vcat(a, p.coeff))

function *(a::Poly, b::Poly)
    return +([ c * vcat(zeros(p - 1), a) for (p, c) in enumerate(b.coeff)]...)
end

function generator(n::Int64)
    *([Poly([logtable[i - 1], 1]) for i in 1:n]...)
end

lead(p::Poly) = last(p.coeff)
init(p::Poly) = Poly(deleteat!(p.coeff, length(p)))
tail(p::Poly) = Poly(deleteat!(p.coeff, 1))

function geterrorcorrection(a::Poly, n::Int)
    la = length(a)
    a = vcat(zeros(n), a)
    g = vcat(zeros(length(a)-n), generator(n))

    for _ in 1:la
        tail(g)
        a = init(lead(a) * g + a)
    end
    return a
end


end
