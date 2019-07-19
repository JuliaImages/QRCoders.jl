module QRCode

using Revise
using Plots
# export Poly, logtable, antilogtable, generator, mult

abstract type Mode end
struct Numeric <: Mode end
struct Alphanumeric <: Mode end
struct Byte <: Mode end
#TODO struct Kanji <: Mode end

abstract type ErrCorrLevel end
struct Low <: ErrCorrLevel end
struct Medium <: ErrCorrLevel end
struct Quartile <: ErrCorrLevel end
struct High <: ErrCorrLevel end

include("tables.jl")
include("errorcorrection.jl")
using .Polynomial
include("matrix.jl")


function getmode(message::AbstractString)
    if all([isdigit(c) for c in message])
        return Numeric()
    elseif all([haskey(alphanumeric, c) for c in message])
        return Alphanumeric()
    else
        return Byte()
    end
end

function getversion(length::Int64, mode::Mode, level::ErrCorrLevel)::Int64
    return findfirst(v->v >= length, characterscapacity[(level, mode)])
end


function getcharactercountlength(version::Int64, mode::Mode)::Int64
    if 1 <= version <= 9
        i = 1
    elseif version <= 26
        i = 2
    else
        i = 3
    end
    return charactercountlength[mode][i]
end

function lpadbitarray(b::BitArray, l::Int64)
    if length(b) >= l
        return b
    else
        return vcat(falses(l - length(b)), b)
    end
end

function encodedata(message::AbstractString, ::Numeric)
    l = length(message)
    chunks = [SubString(message, i, min(i + 2, l)) for i in 1:3:l]

    function toBin(n::Int64) :: BitArray
        if n < 10
            return  BitArray(reverse(digits(n, base = 2, pad = 4)))
        elseif n < 100
            return  BitArray(reverse(digits(n, base = 2, pad = 7)))
        else
            return  BitArray(reverse(digits(n, base = 2, pad = 10)))
        end
    end

    binchunks = map(s -> toBin(parse(Int64, s)), chunks)
    return vcat(binchunks...)
end

function encodedata(message::AbstractString, ::Alphanumeric)
    l = length(message)
    chunks = [SubString(message, i, min(i + 1, l)) for i in 1:2:l]

    function toBin(s::SubString) :: BitArray
        if length(s) == 1
            n = alphanumeric[s[1]]
            return  BitArray(reverse(digits(n, base = 2, pad = 6)))
        else
            n = 45 * alphanumeric[s[1]] + alphanumeric[s[2]]
            return  BitArray(reverse(digits(n, base = 2, pad = 11)))
        end
    end

    binchunks = map(toBin, chunks)
    return vcat(binchunks...)
end

function int2bitarray(n::Int)
    return  BitArray(reverse(digits(n, base = 2, pad = 8)))
end

function encodedata(message::AbstractString, ::Byte)
    bytes = Array{UInt8}(message)
    bin = map(int2bitarray, Array{Int64, 1}(bytes))
    return vcat(bin...)
end


function padencodedmessage(data::BitArray{1}, requiredlentgh::Int64)
    # Add up to 4 zeros to terminate the message
    data = vcat(data, falses(min(4, requiredlentgh - length(data))))

    # Add zeros to make the length a multiple of 8
    if length(data) % 8 != 0
        data = vcat(data, falses(8 - length(data) % 8))
    end

    # Add the repeated pattern until reaching required length
    pattern = BitArray{1}([1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1])
    pad = repeat(pattern, ceil(Int64, requiredlentgh - length(data) / 8))
    data = vcat(data, pad[1:requiredlentgh - length(data)])

    return data
end

function makeblocks(b::BitArray{1},nb1::Int64, dc1::Int64, nb2::Int64, dc2::Int64)
    array = reshape(b, (8, div(length(b), 8)))
    i = 1
    blocks = BitArray{2}[]
    for n in 1:nb1
        push!(blocks, array[:, i:i+dc1-1])
        i += dc1
    end
    for n in 1:nb2
        push!(blocks, array[:, i:i+dc2-1])
        i += dc2
    end
    return blocks
end

function geterrcorrblock(block::BitArray{2}, cw::Int64)
    bitarray2ints(b) = reduce((acc, n) -> 2 * acc + n, b, init=0, dims=1)
    array2poly(a) =  Poly(reverse(a[:]))

    ecpoly = geterrorcorrection(array2poly(bitarray2ints(block)), cw)
    ecarr = map(int2bitarray, reverse(ecpoly.coeff))
    bits = foldl(vcat, ecarr, init = BitArray[])
    return BitArray{2}(reshape(bits, (8, div(length(bits), 8))))
end

function interleave( blocks::Array{BitArray{2}, 1}
                   , ecblocks::Array{BitArray{2}, 1}
                   , ncodewords::Int64
                   , nb1::Int64
                   , dc1::Int64
                   , nb2::Int64
                   , dc2::Int64
                   , version::Int64)

    data = BitArray{1}()
    for i in 1:dc1
        data = foldl( (acc, block) -> vcat(acc, block[:, i])
                    , blocks
                    , init = data
                    )
    end
    if dc2 > dc1
        data = foldl( (acc, block) -> vcat(acc, block[:, dc2])
                    , blocks[nb1 + 1 : nb1 + nb2]
                    , init = data
                    )
    end

    for i in 1:ncodewords
        data = foldl( (acc, block) -> vcat(acc, block[:, i])
                    , ecblocks
                    , init = data
                    )
    end

    data = vcat(data, falses(remainerbits[version]))

    return data
end


function qrcode(message::AbstractString, eclevel = Medium()::ErrCorrLevel)
    # Determining QR code mode and version
    l = length(message)
    mode = getmode(message)
    version = getversion(l, mode, eclevel)

    # Mode indicator: part of the encoded message
    modeindicator = modeindicators[mode]

    # Character count: part of the encoded message
    cclength = getcharactercountlength(version, mode)
    ccindicator = BitArray(reverse(digits(l, base = 2, pad = cclength)))

    # Encoded data: main part of the encoded message
    encodeddata = encodedata(message, mode)

    # Getting parameters for the error correction
    ncodewords, nb1, dc1, nb2, dc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * dc1 + nb2 * dc2)

    # Pad encoded message before error correction
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)

    # Getting error correction codes
    blocks = makeblocks(encoded, nb1, dc1, nb2, dc2)
    errcorrblocks = map(b -> geterrcorrblock(b, ncodewords), blocks)

    # Interleave code blocks
    data = interleave(blocks, errcorrblocks, ncodewords, nb1, dc1, nb2, dc2, version)

    # Generate qr code matrix, masks and fill it
    matrix = emptymatrix(version)
    masks = makemasks(matrix)
    path = getpath(matrix)
    matrix = placedata!(matrix, path, data)

    # Pick the best mask
    candidates = map(enumerate(masks)) do (i, m)
        i - 1, xor.(matrix, m)
    end
    mask, matrix = first(sort(candidates, by = penalty ∘ last))

    # Format and version information
    matrix = addformat(matrix, mask, version, eclevel)

    return matrix

end

end # module
