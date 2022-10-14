"""
Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.
"""
module QRCoders

# create QR code
export qrcode, exportqrcode

# supported modes
export Mode, Numeric, Alphanumeric, Byte, Kanji, UTF8

# error correction levels
export ErrCorrLevel, Low, Medium, Quartile, High

# get information about QR code
export getmode, getversion

# data type of Reed Solomon code
export Poly, geterrcode

# error type
export EncodeError

# QR code style
export unicodeplot, unicodeplotbychar

using ImageCore
using FileIO
using UnicodePlots

"""
Invalid step in encoding process.
"""
struct EncodeError <: Exception
    st::AbstractString
end

# Encoding mode of the QR code
"""
Abstract type that groups the five supported encoding modes `Numeric`,
`Alphanumeric`, `Byte`, `Kanji` and `UTF8`.
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
Encoding mode for messages composed of one-byte characters(unicode range from
0x00 to 0xff, including ISO-8859-1 and undefined characters)
"""
struct Byte <: Mode end
"""
Encoding mode for messages composed of Shift JIS(Shift Japanese Industrial Standards) characters.
"""
struct Kanji <: Mode end
"""
Encoding mode for messages composed of utf-8 characters.
"""
struct UTF8 <: Mode end

# relationships between the encoding modes
import Base: issubset
"""
    issubset(mode1::Mode, mode2::Mode)
    ⊆(mode1::Mode, mode2::Mode)

Returns `true` if the character set of `mode1` is a subset of the character set of `mode2`.
"""
issubset(::Mode, ::UTF8) = true
issubset(mode::Mode, ::Numeric) = mode == Numeric()
issubset(mode::Mode, ::Alphanumeric) = (mode == Alphanumeric() || mode == Numeric())
issubset(mode::Mode, ::Byte) = (mode != UTF8() && mode != Kanji())
issubset(mode::Mode, ::Kanji) = mode == Kanji()

# Error correction level of the QR code
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
include("style.jl")

"""
    qrcode( message::AbstractString
          ; eclevel::ErrCorrLevel = Medium()
          , version::Int = 0
          , mode::Mode = Numeric()
          , mask::Int = -1
          , width::Int=0)

Create a `BitArray{2}` with the encoded `message`, with `true` (`1`) for the black
areas and `false` (`0`) as the white ones.

The error correction level `eclevel` can be picked from four values: `Low()`
(7% of missing data can be restored), `Medium()` (15%), `Quartile()` (25%) or
`High()` (30%). Higher levels make denser QR codes.

The version of the QR code can be picked from 1 to 40. If the assigned version is 
too small to contain the message, the first available version is used.

The encoding mode `mode` can be picked from five values: `Numeric()`, `Alphanumeric()`,
`Byte()`, `Kanji()` or `UTF8()`. If the assigned `mode` is `nothing` or failed to contain the message,
the mode is automatically picked.

The mask pattern `mask` can be picked from 0 to 7. If the assigned `mask` is `nothing`,
the mask pattern will picked by the penalty rules.


"""
function qrcode( message::AbstractString
               ; eclevel::ErrCorrLevel = Medium()
               , version::Int = 0
               , mode::Mode = Numeric()
               , mask::Int = -1
               , compact::Bool = false
               , width::Int = 0)
    # Determining mode and version of the QR code
    bestmode = getmode(message)
    mode = bestmode ⊆ mode ? mode : bestmode
    
    minversion = getversion(message, mode, eclevel)
    if version < minversion # the specified version is too small
        version = minversion
    end

    # encode message
    data = encodemessage(message, mode, eclevel, version)

    # Generate qr code matrix
    matrix = emptymatrix(version)
    masks = makemasks(matrix) # 8 masks
    matrix = placedata!(matrix, data) # fill in data bits
    addversion!(matrix, version) # fill in version bits

    # Apply mask and add format information
    maskedmats = [addformat!(xor.(matrix, mat), i-1, eclevel) 
                  for (i, mat) in enumerate(masks)]
    
    # Pick the best mask
    if !(0 ≤ mask ≤ 7) # invalid mask
        mask = argmin(penalty.(maskedmats)) - 1
    end
    matrix = maskedmats[mask + 1]

    # Format and version information
    (compact || width == 0) && return matrix # keyword compact will be removed in the future
    background = falses(size(matrix) .+ (width*2, width*2))
    background[width+1:end-width, width+1:end-width] = matrix
    return background
end

"""
    exportqrcode( message::AbstractString
                , path::AbstractString = "qrcode.png"
                ; eclevel::ErrCorrLevel = Medium()
                , version::Int = 0
                , mode::Union{Nothing, Mode} = nothing
                , targetsize::Int = 5
                , width::int=4)

Create a `PNG` file with the encoded `message` of approximate size `targetsize`
cm. If `compact` is `false`, white space is added around the QR code.

The error correction level `eclevel` can be picked from four values: `Low()`
(7% of missing data can be restored), `Medium()` (15%), `Quartile()` (25%) or
`High()` (30%). Higher levels make denser QR codes.

The version of the QR code can be picked from 1 to 40. If the assigned version is 
too small to contain the message, the first available version is used.

The encoding mode `mode` can be picked from four values: `Numeric()`, `Alphanumeric()`,
`Byte()`, `Kanji()` or `UTF8()`. If the assigned `mode` is `nothing` or failed to contain the message,
the mode is automatically picked.

The mask pattern `mask` can be picked from 0 to 7. If the assigned `mask` is `nothing`,
the mask pattern will picked by the penalty rules.
"""
function exportqrcode( message::AbstractString
                     , path::AbstractString = "qrcode.png"
                     ; eclevel::ErrCorrLevel = Medium()
                     , version::Int = 0
                     , mode::Mode = Numeric()
                     , mask::Int = -1
                     , targetsize::Int = 5
                     , compact::Bool = false
                     , width::Int = 4 )
    # check if the image format is supported
    supportexts = ["png", "jpg"]
    if isnothing(match(r"\.\w+", path))
        path *= ".png"
    else
        ext = match(r"\.(\w+)", path).captures[1]
        ext ∈ supportexts || throw(EncodeError(
            "Unsupported file extension: $ext\n Supported extensions: $supportexts"))
    end
    # encode data
    matrix = qrcode(message; eclevel=eclevel,
                             version=version,
                             mode=mode,
                             mask=mask,
                             compact=compact,
                             width=width)
    # Seems the default setting is 72 DPI
    pixels = size(matrix, 1)
    scale = ceil(Int, 72 * targetsize / 2.45 / pixels)
    matrix = kron(matrix, trues(scale, scale))

    save(path, BitArray(.! matrix))
end

end # module
