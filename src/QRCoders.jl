"""
Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.
"""
module QRCoders

# create QR code
export qrcode, exportqrcode, QRCode

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

"""
    QRCode

A type that represents a QR code.

# Fields
- `version::Int`: version of the QR code
- `mode::Mode`: encoding mode of the QR code
- `eclevel::ErrCorrLevel`: error correction level of the QR code
- `mask::Int`: mask pattern of the QR code
- `message::AbstractString`: message to be encoded
- `width::Int`: width of the white border
"""
mutable struct QRCode
    version::Int # version of the QR code
    mode::Mode # encoding mode
    eclevel::ErrCorrLevel
    mask::Int # mask pattern
    message::AbstractString # message to be encoded
    width::Int # width of the white border
end

"""
    QRCode(message::AbstractString)

Create a QR code with the default settings.
"""
function QRCode( message::AbstractString
               ; mask = -1
               , eclevel = Medium()
               , mode = Numeric()
               , version = 0
               , width = 1)
    minmode = getmode(message)
    mode = issubset(minmode, mode) ? mode : minmode
    minversion = getversion(message, mode, eclevel)
    version = version ≥ minversion ? version : minversion
    # valid mask pattern (0-7)
    0 ≤ mask ≤ 7 && return QRCode(version, mode, eclevel, mask, message, width)

    # find the best mask
    data = encodemessage(message, mode, eclevel, version)
    matrix = emptymatrix(version)
    masks = makemasks(matrix)
    matrix = placedata!(matrix, data) # fill in data bits
    addversion!(matrix, version) # fill in version bits

    # Apply mask and add format information
    maskedmats = [addformat!(xor.(matrix, mat), i-1, eclevel) 
                  for (i, mat) in enumerate(masks)]
    
    # Pick the best mask
    mask = argmin(penalty.(maskedmats)) - 1
    QRCode(version, mode, eclevel, mask, message, width)
end

"""
    shape(code::QRCode)

Return the shape of the QR code.
"""
function shape(code::QRCode)
    n = 4 * code.version + 17 + 2 * code.width
    n, n
end

"""
    show(io::IO, code::QRCode)

Show the QR code in REPL using `unicodeplotbycahr`.
"""
Base.show(io::IO, code::QRCode) = print(io, unicodeplotbychar(.! qrcode(code)))

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

    # white border
    (compact || width == 0) && return matrix # keyword compact will be removed in the future
    background = falses(size(matrix) .+ (width*2, width*2))
    background[width+1:end-width, width+1:end-width] = matrix
    return background
end

"""
    exportbitmat(matrix::BitMatrix, path::AbstractString; targetsize::Int=5)
    
Export the `BitMatrix` `matrix` to an image with file path `path`.
"""
function exportbitmat(matrix::BitMatrix, path::AbstractString; targetsize::Int = 5)
    # check whether the image format is supported
    supportexts = ["png", "jpg", "gif"]
    if !endswith(path, r"\.\w+")
        path *= ".png"
    else
        ext = last(split(path, '.'))
        ext ∈ supportexts || throw(EncodeError(
            "Unsupported file extension: $ext\n Supported extensions: $supportexts"))
    end

    # Seems the default setting is 72 DPI
    pixels = size(matrix, 1)
    scale = ceil(Int, 72 * targetsize / 2.45 / pixels)
    matrix = kron(matrix, trues(scale, scale))

    save(path, BitArray(.! matrix))
end

"""
    exportqrcode( message::AbstractString
                , path::AbstractString = "qrcode.png"
                ; eclevel::ErrCorrLevel = Medium()
                , version::Int = 0
                , mode::Union{Nothing, Mode} = nothing
                , targetsize::Int = 5
                , width::int=4)

Create an image with the encoded `message` of approximate size `targetsize`
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
                     , width::Int = 4
                     , compact::Bool = false
                     , targetsize::Int = 5)
    # encode data
    matrix = qrcode(message; eclevel=eclevel,
                             version=version,
                             mode=mode,
                             mask=mask,
                             compact=compact,
                             width=width)
    exportbitmat(matrix, path; targetsize=targetsize)
end

# new API for qrcode and exportqrcode
"""
    qrcode(code::QRCode)

Create a QR code matrix by the `QRCode` object.

Note: It would raise an error if failed to use the specified `mode`` or `version`.
"""
function qrcode(code::QRCode)
    # raise error if failed to use the specified mode or version
    mode, eclevel, version, mask = code.mode, code.eclevel, code.version, code.mask
    message, width = code.message, code.width
    getmode(message) ⊆ mode || throw(EncodeError("Mode $mode can not encode the message"))
    getversion(message, mode, eclevel) < version && throw(EncodeError("The version $version is too small"))

    # encode message
    data = encodemessage(message, mode, eclevel, version)

    # Generate qr code matrix
    matrix = emptymatrix(version)
    maskmat = makemask(matrix, mask)
    matrix = placedata!(matrix, data) # fill in data bits
    addversion!(matrix, version) # fill in version bits
    matrix = addformat!(xor.(matrix, maskmat), mask, eclevel)

    # white border
    width == 0 && return matrix
    background = falses(size(matrix) .+ (width*2, width*2))
    background[width+1:end-width, width+1:end-width] = matrix
    return background
end

"""
    exportqrcode( code::QRCode
                , path::AbstractString = "qrcode.png"
                ; targetsize::Int = 5)

Create an image with the encoded `message` of approximate size `targetsize`.
"""
function exportqrcode( code::QRCode
                     , path::AbstractString = "qrcode.png"
                     ; targetsize::Int = 5)
    matrix = qrcode(code)
    exportbitmat(matrix, path; targetsize = targetsize)
end

"""
    exportqrcode( codes::AbstractVector{QRCode}
                , path::AbstractString = "qrcode.gif"
                ; targetsize::Int = 5
                , fps::Int = 2)

Create an animated gif with `codes` of approximate size `targetsize`.

The frame rate `fps` is the number of frames per second.

Note: The `codes` should have the same size while the other properties can be different.
"""
function exportqrcode( codes::AbstractVector{QRCode}
                     , path::AbstractString = "qrcodes.gif"
                     ; targetsize::Int = 5
                     , fps::Int = 2)
    # check whether the image format is supported
    if !endswith(path, r"\.\w+")
        path *= ".gif"
    else
        ext = last(split(path, '.'))
        ext == "gif" || throw(EncodeError(
            "$ext\n is not a valid format for animated images"))
    end
    # code = cat(qrcode.(codes)...; dims=3)
    n, _ = shape(first(codes))
    scale = ceil(Int, 72 * targetsize / 2.45 / n)
    code = Array{Bool}(undef, n * scale, n * scale, length(codes))
    for (i, c) in enumerate(codes)
        mat = qrcode(c)
        code[:,:,i] = kron(mat, trues(scale, scale))
    end
    save(path, BitArray(.! code), fps=fps)
end

"""
    exportqrcode( msgs::AbstractVector{<:AbstractString}
                , path::AbstractString = "qrcodes.gif"
                ; eclevel::ErrCorrLevel = Medium()
                , version::Int = 0
                , mode::Mode = Numeric()
                , mask::Int = -1
                , width::Int = 4
                , targetsize::Int = 5
                , fps::Int = 2)

Create an animated gif with `msgs` of approximate size `targetsize`.

The frame rate `fps` is the number of frames per second.
"""
function exportqrcode( msgs::AbstractVector{<:AbstractString}
                     , path::AbstractString = "qrcodes.gif"
                     ; eclevel::ErrCorrLevel = Medium()
                     , version::Int = 0
                     , mode::Mode = Numeric()
                     , mask::Int = -1
                     , width::Int = 4
                     , targetsize::Int = 5
                     , fps::Int = 2)
    codes = QRCode.( msgs
                   ; eclevel=eclevel
                   , version=version
                   , mode=mode
                   , mask=mask
                   , width=width)
    exportqrcode(codes, path; targetsize=targetsize, fps=fps)
end

end # module
