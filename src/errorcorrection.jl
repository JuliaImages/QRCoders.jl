
const modulo = 285

function makelogtable()
    t = ones(UInt8, 256)
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

const logtable = Dict{UInt8,UInt8}(zip(0:255, makelogtable()))

const antilogtable = Dict{UInt8,UInt8}(zip(makelogtable(), 0:254))

function mult(a::UInt8, b::UInt8)
    xa = antilogtable[a]
    xb = antilogtable[b]
    return logtable[(xa + xb) % 256]
end

struct Poly
    coeff::Array{UInt8, 1}
end

function Base.:length(p::Poly)
    return length(p.coeff)
end

function Base.:+(a::Poly, b::Poly)
    l = max(length(a), length(b))
    return Poly([xor(get(a.coeff,i,0),get(b.coeff,i,0)) for i in 1:l])
end

function Base.:*(a::UInt8, p::Poly)
    return Poly(map(x -> mult(a, x), p.coeff))
end

function Base.:iterate(p::Poly)
    return Poly(iterate(p.coeff))
end

function Base.:*(a::Poly, b::Poly)
    return +([ c*prepend!(zeros(p), a) for (p, c) in enumerate(b.coeff)]...)
end
