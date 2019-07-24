"""
Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.
"""
module QRCode

export Mode, Numeric, Alphanumeric, Byte
export ErrCorrLevel, Low, Medium, Quartile, High
export getmode, getversion, qrcode, exportqrcode

using Images
using FileIO
add_saver(format"PNG", :ImageMagick)

using Compat # isnothing is not defined in Julia 1.0

"""
Abstract type that groups the three supported encoding modes `Numeric`,
`Alphanumeric` and `Byte`.
"""
abstract type Mode end
"""
Encoding mode for messages composed of digits only.
"""
struct Numeric <: Mode end
"""
Encoding mode for messages composed of digits, characters `A`-`Z` (capital only)
, space and `%` `*` `+` `-` `.` `/` `:` `\$`.
"""
struct Alphanumeric <: Mode end
"""
Encoding mode for messages composed of ISO 8859-1 or UTF-8 characters.
"""
struct Byte <: Mode end
# struct Kanji <: Mode end

"""
Abstract type that groups the four error correction levels `Low`, `Medium`,
`Quartile` and `High`.
"""
abstract type ErrCorrLevel end
"""
Error correction level that can restore up to 7% of missing codewords.
"""
struct Low <: ErrCorrLevel end
"""
Error correction level that can restore up to 15% of missing codewords.
"""
struct Medium <: ErrCorrLevel end
"""
Error correction level that can restore up to 25% of missing codewords.
"""
struct Quartile <: ErrCorrLevel end
"""
Error correction level that can restore up to 30% of missing codewords.
"""
struct High <: ErrCorrLevel end

include("tables.jl")
include("errorcorrection.jl")
include("matrix.jl")

using .Polynomial

"""
    getmode(message::AbstractString)

Return the encoding mode of `message`, either `Numeric()`, `Alphanumeric()`
or `Byte()`.

# Examples
```jldoctest
julia> getmode("HELLO WORLD")
Alphanumeric()
```
"""
function getmode(message::AbstractString)::Mode
    if all([isdigit(c) for c in message])
        return Numeric()
    elseif all([haskey(alphanumeric, c) for c in message])
        return Alphanumeric()
    else
        return Byte()
    end
end

"""
    getversion(message::AbstractString, mode::Mode, level::ErrCorrLevel)

Return the version of the QR code, between 1 and 40.

```jldoctest
julia> getversion("Hello World!", Alphanumeric(), High())
2
```
"""
function getversion(message::AbstractString, mode::Mode, level::ErrCorrLevel)::Int64
    cc = characterscapacity[(level, mode)]
    return findfirst(v->v >= lastindex(message), cc)
end

"""
    getcharactercountindicator(msglength::Int64, version::Int64, mode::Mode)

Return the bits for character count indicator.
"""
function getcharactercountindicator(msglength::Int64,
                                    version::Int64,
                                    mode::Mode)::BitArray{1}
    if 1 <= version <= 9
        i = 1
    elseif version <= 26
        i = 2
    else
        i = 3
    end
    cclength = charactercountlength[mode][i]
    indicator = BitArray(reverse(digits(msglength, base = 2, pad = cclength)))

    return indicator
end

"""
    encodedata(message::AbstractString, ::Mode)

Encode the message with the given mode.
"""
function encodedata(message::AbstractString, ::Numeric)::BitArray{1}
    l = length(message)
    chunks = [SubString(message, i, min(i + 2, l)) for i in 1:3:l]

    function toBin(chunk::SubString)::BitArray
        pad = 1 + 3 * length(chunk)
        n = parse(Int64, chunk)
        return  BitArray(reverse(digits(n, base = 2, pad = pad)))
    end

    binchunks = map(toBin, chunks)
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

"""
    int2bitarray(n::Int64)

Encode an integer into a `BitArray`.
"""
function int2bitarray(n::Int64)::BitArray{1}
    return  BitArray(reverse(digits(n, base = 2, pad = 8)))
end

"""
    padencodedmessage(data::BitArray{1}, requiredlentgh::Int64)

Pad the encoded message.
"""
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

"""
    makeblocks(bits::BitArray{1}, nb1::Int64, dc1::Int64, nb2::Int64, dc2::Int64)

Divide the encoded message into 1 or 2 blocks with `nbX` blocks in group `X` and
`dcX` codewords per block.
"""
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

"""
    geterrcorrblock(block::BitArray{2}, ncodewords::Int64)

Return the error correction blocks, with `ncodewords` codewords per block.
"""
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

"""
    interleave(blocks::Array{BitArray{2},1}, ecblocks::Array{BitArray{2},1},
               ncodewords::Int64, nb1::Int64, dc1::Int64, nb2::Int64, dc2::Int64,
               version::Int64)

Mix the encoded data blocks and error correction blocks.
"""
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
    data = vcat(data, falses(remainderbits[version]))

    return data
end

"""
    qrcode(message::AbstractString, eclevel = Medium(); compact = false)

Create a `BitArray{2}` with the encoded `message`, with `true` (`1`) for the black
areas and `false` (`0`) as the white ones. If `compact` is `false`, white space
is added around the QR code.

The error correction level `eclevel` can be picked from four values: `Low()`
(7% of missing data can be restored), `Medium()` (15%), `Quartile()` (25%) or
`High()` (30%). Higher levels make denser QR codes.
"""
function qrcode( message::AbstractString
               , eclevel::ErrCorrLevel = Medium()
               ; compact::Bool = false )
    # Determining QR code mode and version
    mode = getmode(message)
    version = getversion(message, mode, eclevel)

    # Mode indicator: part of the encoded message
    modeindicator = modeindicators[mode]

    # Character count: part of the encoded message
    ccindicator = getcharactercountindicator(lastindex(message), version, mode)

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

    if compact
        return matrix
    else
        background = falses(size(matrix) .+ (8, 8))
        background[5:end-4, 5:end-4] = matrix
        return background
    end
end

"""
    exportqrcode( message::AbstractString
                , path = "qrcode.png"
                , eclevel = Medium()
                ; targetsize = 5
                , compact = false )

Create a `PNG` file with the encoded `message` of approximate size `targetsize`
cm. If `compact` is `false`, white space is added around the QR code.

The error correction level `eclevel` can be picked from four values: `Low()`
(7% of missing data can be restored), `Medium()` (15%), `Quartile()` (25%) or
`High()` (30%). Higher levels make denser QR codes.
"""
function exportqrcode( message::AbstractString
                     , path::AbstractString = "qrcode.png"
                     , eclevel::ErrCorrLevel = Medium()
                     ; targetsize::Int64 = 5
                     , compact::Bool = false )

    matrix = qrcode(message, eclevel, compact = compact)

    if !endswith(path, ".png")
        path = "$path.png"
    end

    # Seems the default setting is 72 DPI
    pixels = size(matrix, 1)
    scale = ceil(Int64, 72 * targetsize / 2.45 / pixels)
    matrix = kron(matrix, trues((scale, scale)))

    save(path, colorview(Gray, .! matrix))
end

end # module
