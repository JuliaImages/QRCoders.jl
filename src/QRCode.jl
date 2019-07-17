module QRCode

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

function encodedata(message::AbstractString, mode::Numeric)
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

function encodedata(message::AbstractString, mode::Alphanumeric)
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

function int2bitarray(:: BitArray, n::UInt8)
    return  BitArray(reverse(digits(n, base = 2, pad = 8)))
end


function encodedata(message::AbstractString, mode::Byte)
    bytes = Array{UInt8}(message)
    bin = map(int2bitarray, bytes)
    return vcat(bin...)
end

function getrequiredbits(level::ErrCorrLevel, version::Int64)
    _, nb1, dc1, nb2, dc2 = ecblockinfo[level][version, :]
    return 8 * (nb1 * dc1 + nb2 * dc2)
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

function makeblocks(b::BitArray{2},level::ErrCorrLevel, version::Int64)
    _, nb1, dc1, nb2, dc2 = ecblockinfo[level][version, :]
    i = 1
    blocks = BitArray{2}[]
    for n in 1:nb1
        push!(blocks, b[:, i:i+dc1-1])
        i += dc1
    end
    for n in 1:nb2
        push!(blocks, b[:, i:i+dc2-1])
        i += dc2
    end
    return blocks
end

function geterrcorrblocks(blocks::Array{BitArray{2}, 1},level::ErrCorrLevel, version::Int64)
    l = ecblockinfo[level][version, 1]
    bitarray2int(b) = reduce((acc, n) -> 2 * acc + n, b, init=0, dims=1)
    errcorr = map(b -> geterrorcorrection(Poly(reverse(bitarray2int(b)[:])), l), blocks)
    return errcorr
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

    # Pad encoded message before error correction
    requiredbits = getrequiredbits(eclevel, version)
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)

    # Getting error correction codes
    array = reshape(encoded, (8, div(requiredbits, 8)))
    blocks = makeblocks(array, eclevel, version)
    errcorrblocks = geterrcorrblocks(blocks, eclevel, version)


    return errcorrblocks
end

end # module
