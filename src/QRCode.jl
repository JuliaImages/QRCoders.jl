module QRCode

export Mode, Numeric, Alphanumeric, Byte
export ErrCorrLevel, Low, Medium, Quartile, High
export getmode, getversion, qrcode

abstract type Mode end
struct Numeric <: Mode end
struct Alphanumeric <: Mode end
struct Byte <: Mode end
# struct Kanji <: Mode end

abstract type ErrCorrLevel end
struct Low <: ErrCorrLevel end
struct Medium <: ErrCorrLevel end
struct Quartile <: ErrCorrLevel end
struct High <: ErrCorrLevel end

include("tables.jl")
include("errorcorrection.jl")
include("matrix.jl")

using .Polynomial

function getmode(message::AbstractString)::Mode
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

function getcharactercountindicator(l::Int64, version::Int64, mode::Mode)::BitArray{1}
    if 1 <= version <= 9
        i = 1
    elseif version <= 26
        i = 2
    else
        i = 3
    end
    cclength = charactercountlength[mode][i]
    indicator = BitArray(reverse(digits(l, base = 2, pad = cclength)))

    return indicator
end

function encodedata(message::AbstractString, ::Numeric)::BitArray{1}
    l = length(message)
    chunks = [SubString(message, i, min(i + 2, l)) for i in 1:3:l]

    function toBin(n::Int64)::BitArray
        if n < 10
            return  BitArray(reverse(digits(n, base = 2, pad = 4)))
        elseif n < 100
            return  BitArray(reverse(digits(n, base = 2, pad = 7)))
        else
            return  BitArray(reverse(digits(n, base = 2, pad = 10)))
        end
    end

    binchunks = map(s->toBin(parse(Int64, s)), chunks)
    return vcat(binchunks...)
end

function encodedata(message::AbstractString, ::Alphanumeric)::BitArray{1}
    l = length(message)
    chunks = [SubString(message, i, min(i + 1, l)) for i in 1:2:l]

    function toBin(s::SubString)::BitArray{1}
        if length(s) == 1
            n = alphanumeric[s[1]]
            return  BitArray{1}(reverse(digits(n, base = 2, pad = 6)))
        else
            n = 45 * alphanumeric[s[1]] + alphanumeric[s[2]]
            return  BitArray{1}(reverse(digits(n, base = 2, pad = 11)))
        end
    end

    binchunks = map(toBin, chunks)
    return vcat(binchunks...)
end

function encodedata(message::AbstractString, ::Byte)::BitArray{1}
    bytes = Array{UInt8}(message)
    bin = map(int2bitarray, Array{Int64,1}(bytes))
    return vcat(bin...)
end

function int2bitarray(n::Int64)::BitArray{1}
    return  BitArray(reverse(digits(n, base = 2, pad = 8)))
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

function makeblocks(bits::BitArray{1},
                    nb1::Int64,
                    dc1::Int64,
                    nb2::Int64,
                    dc2::Int64)::Array{BitArray{2},1}
    array = reshape(bits, (8, length(bits) ÷ 8))
    i = 1
    blocks = BitArray{2}[]
    for n in 1:nb1
        push!(blocks, array[:, i:i + dc1 - 1])
        i += dc1
    end
    for n in 1:nb2
        push!(blocks, array[:, i:i + dc2 - 1])
        i += dc2
    end
    return blocks
end

function geterrcorrblock(block::BitArray{2}, ncodewords::Int64)::BitArray{2}
    # Helper functions
    bitarray2ints(b) = reduce((acc, n)->2 * acc + n, b, init = 0, dims = 1)
    array2poly(a) =  Poly(reverse(a[:]))

    poly = array2poly(bitarray2ints(block))
    ecpoly = geterrorcorrection(poly, ncodewords)
    ecarray = map(int2bitarray, reverse(ecpoly.coeff))
    ecbits = foldl(vcat, ecarray, init = BitArray{1}())
    return reshape(ecbits, (8, length(ecbits) ÷ 8))
end

function interleave( blocks::Array{BitArray{2},1}
                   , ecblocks::Array{BitArray{2},1}
                   , ncodewords::Int64, nb1::Int64
                   , dc1::Int64
                   , nb2::Int64
                   , dc2::Int64
                   , version::Int64
                   )::BitArray{1}

    data = BitArray{1}()

    slice(i) = (acc, block) -> vcat(acc, block[:, i])

    # Encoded data
    for i in 1:dc1
        data = foldl(slice(i), blocks, init = data)
    end
    if dc2 > dc1
        data = foldl(slice(dc2), blocks[nb1 + 1 : nb1 + nb2], init = data)
    end

    # Error correction data
    for i in 1:ncodewords
        data = foldl(slice(i), ecblocks, init = data)
    end

    # Extra padding
    data = vcat(data, falses(remainerbits[version]))

    return data
end

function qrcode(message::AbstractString, eclevel::ErrCorrLevel = Medium())
    # Determining QR code mode and version
    l = length(message)
    mode = getmode(message)
    version = getversion(l, mode, eclevel)

    # Mode indicator: part of the encoded message
    modeindicator = modeindicators[mode]

    # Character count: part of the encoded message
    ccindicator = getcharactercountindicator(l, version, mode)

    # Encoded data: main part of the encoded message
    encodeddata = encodedata(message, mode)

    # Getting parameters for the error correction
    # Number of error correction codewords per block, number of blocks in
    # group 1/2, number of data codewords per block in group 1/2
    ncodewords, nb1, dc1, nb2, dc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * dc1 + nb2 * dc2)

    # Pad encoded message before error correction
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)

    # Getting error correction codes
    blocks = makeblocks(encoded, nb1, dc1, nb2, dc2)
    ecblocks = map(b->geterrcorrblock(b, ncodewords), blocks)

    # Interleave code blocks
    data = interleave(blocks, ecblocks, ncodewords, nb1, dc1, nb2, dc2, version)

    # Generate qr code matrix, masks and fill it
    matrix = emptymatrix(version)
    masks = makemasks(matrix)
    matrix = placedata!(matrix, data)

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
