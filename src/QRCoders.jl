"""
Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.
"""
module QRCoders

export Mode, Numeric, Alphanumeric, Byte
export ErrCorrLevel, Low, Medium, Quartile, High
export getmode, getversion, qrcode, exportqrcode
export Poly

using ImageCore
using FileIO

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
"""
Encoding mode for messages composed of Shift JIS(Shift Japanese Industrial Standards) characters.
"""
struct Kanji <: Mode end

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
include("encode.jl")

"""
    int2bitarray(n::Int)

Encode an integer into a `BitArray`.
"""
int2bitarray(n::Int) = BitArray(reverse!(digits(n, base = 2, pad = 8)))

"""
    bitarray2int(bits::AbstractVector)

Convert a bitarray to an integer.
"""
bitarray2int(bits::AbstractVector) = foldl((i, j) -> (i << 1 ⊻ j), bits)

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
               ; compact::Bool = false
               , version::Int = 0 )
    # Determining QR code mode and version
    mode = getmode(message)
    minversion = getversion(message, mode, eclevel)
    if version < minversion # the specified version is too small
        version = minversion
    end

    # encode message
    data = encodemessage(message, mode, eclevel, version)

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
                     ; targetsize::Int = 5
                     , compact::Bool = false )

    matrix = qrcode(message, eclevel, compact = compact)

    if !endswith(path, ".png")
        path = "$path.png"
    end

    # Seems the default setting is 72 DPI
    pixels = size(matrix, 1)
    scale = ceil(Int, 72 * targetsize / 2.45 / pixels)
    matrix = kron(matrix, trues((scale, scale)))

    save(path, BitArray(.! matrix))
end

end # module
