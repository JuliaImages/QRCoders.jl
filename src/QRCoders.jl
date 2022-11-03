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
export getmode, getversion, qrwidth

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
- `message::String`: message to be encoded
- `border::Int`: width of the white border
"""
mutable struct QRCode
    version::Int # version of the QR code
    mode::Mode # encoding mode
    eclevel::ErrCorrLevel
    mask::Int # mask pattern
    message::String # message to be encoded
    border::Int # width of the white border
end

"""
    QRCode(message::AbstractString)

Create a QR code with the default settings.
"""
function QRCode( message::AbstractString
               ; mask::Int = -1
               , eclevel::ErrCorrLevel = Medium()
               , mode::Mode = Numeric()
               , version::Int = 0
               , width::Int = 1)
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
    qrwidth(code::QRCode)

Return the width of the QR code.
"""
qrwidth(code::QRCode) = 4 * code.version + 17 + 2 * code.border

"""
    show(io::IO, code::QRCode)

Show the QR code in REPL using `unicodeplotbychar`.
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
    
    version > 40 && throw(EncodeError("Version $version should be no larger than 40"))
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
    _resize(matrix::AbstractMatrix, widthpixels::Int)

Resize the width of the QR code to `widthpixels` pixels(approximately).

Note: the size of the resulting matrix is an integer multiple of the size of the original one.
"""
function _resize(matrix::AbstractMatrix, widthpixels::Int = 160)
    scale = ceil(Int, widthpixels / size(matrix, 1))
    kron(matrix, trues(scale, scale))
end

"""
    exportbitmat(matrix::BitMatrix, path::AbstractString; pixels::Int = 160)
    
Export the `BitMatrix` `matrix` to an image with file path `path`.
"""
function exportbitmat( matrix::BitMatrix
                     , path::AbstractString
                     ; targetsize::Int=0
                     , pixels::Int=160)
    # check whether the image format is supported
    supportexts = ["png", "jpg", "gif"]
    if !endswith(path, r"\.\w+")
        path *= ".png"
    else
        ext = last(split(path, '.'))
        ext ∈ supportexts || throw(EncodeError(
            "Unsupported file extension: $ext\n Supported extensions: $supportexts"))
    end
    # resize the matrix
    if targetsize > 0 # original keyword -- will be removed in the future
        n = size(matrix, 1)
        pixels = ceil(Int, 72 * targetsize / 2.45 / n) * n
    end
    save(path, BitArray(.! _resize(matrix, pixels)))
end

"""
    exportqrcode( message::AbstractString
                , path::AbstractString = "qrcode.png"
                ; eclevel::ErrCorrLevel = Medium()
                , version::Int = 0
                , mode::Mode = nothing
                , width::int = 4
                , pixels::Int = 160)

Create an image with the encoded `message` of approximate size `pixels x pixels`.

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
                     , targetsize::Int = 0
                     , pixels::Int = 160)
    # encode data
    matrix = qrcode(message; eclevel=eclevel,
                             version=version,
                             mode=mode,
                             mask=mask,
                             compact=compact,
                             width=width)
    exportbitmat(matrix, path; targetsize=targetsize, pixels=pixels)
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
    message, width = code.message, code.border
    getmode(message) ⊆ mode || throw(EncodeError("Mode $mode can not encode the message"))
    getversion(message, mode, eclevel) ≤ version ≤ 40 || throw(EncodeError("The version $version is too small"))

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
                ; pixels::Int = 160)

Create an image with the encoded `message` of approximate size `targetsize`.
"""
function exportqrcode( code::QRCode
                     , path::AbstractString = "qrcode.png"
                     ; targetsize::Int = 0
                     , pixels::Int = 160)
    matrix = qrcode(code)
    exportbitmat(matrix, path; targetsize=targetsize, pixels=pixels)
end

"""
    exportqrcode( codes::AbstractVector{QRCode}
                , path::AbstractString = "qrcode.gif"
                ; pixels::Int = 160
                , fps::Int = 2)

Create an animated gif with `codes` of approximate size `targetsize`.

The frame rate `fps` is the number of frames per second.

Note: The `codes` should have the same size while the other properties can be different.
"""
function exportqrcode( codes::AbstractVector{QRCode}
                     , path::AbstractString = "qrcode.gif"
                     ; targetsize::Int = 0
                     , pixels::Int = 160
                     , fps::Int = 2)
    # all equal valid only in Julia 1.8+
    length(unique!(qrwidth.(codes))) == 1 || throw(EncodeError("The codes should have the same size"))
    targetwidth = qrwidth(first(codes))
    # check whether the image format is supported
    if !endswith(path, r"\.\w+")
        path *= ".gif"
    else
        ext = last(split(path, '.'))
        ext == "gif" || throw(EncodeError(
            "$ext\n is not a valid format for animated images"))
    end
    # generate frames
    if targetsize > 0 # original keyword -- will be removed in the future
        pixels = ceil(Int, 72 * targetsize / 2.45 / targetwidth) * targetwidth
    end
    pixels = pixels ÷ targetwidth * targetwidth
    code = Array{Bool}(undef, pixels, pixels, length(codes))
    for (i, c) in enumerate(codes)
        code[:,:,i] = _resize(qrcode(c), pixels)
    end
    save(path, BitArray(.! code), fps=fps)
end

"""
    exportqrcode( msgs::AbstractVector{<:AbstractString}
                , path::AbstractString = "qrcode.gif"
                ; eclevel::ErrCorrLevel = Medium()
                , version::Int = 0
                , mode::Mode = Numeric()
                , mask::Int = -1
                , width::Int = 4
                , targetsize::Int = 5
                , pixels::Int = 160
                , fps::Int = 2)

Create an animated gif with `msgs` of approximate size `pixels x pixels`.

The frame rate `fps` is the number of frames per second.
"""
function exportqrcode( msgs::AbstractVector{<:AbstractString}
                     , path::AbstractString = "qrcode.gif"
                     ; eclevel::ErrCorrLevel = Medium()
                     , version::Int = 0
                     , mode::Mode = Numeric()
                     , mask::Int = -1
                     , width::Int = 4
                     , targetsize::Int = 0
                     , pixels::Int = 160
                     , fps::Int = 2)
    codes = QRCode.( msgs
                   ; eclevel=eclevel
                   , version=version
                   , mode=mode
                   , mask=mask
                   , width=width)
    # the image should have the same size
    ## method 1: edit version
    version = maximum(getproperty.(codes, :version))
    setproperty!.(codes, :version, version)
    ## method 2: enlarge width of the small ones
    # maxwidth = first(maximum(qrwidth.(codes)))
    # for code in codes
    #     code.border += (maxwidth - qrwidth(code)) ÷ 2
    # end
    # setproperty!.(codes, :width, width)
    exportqrcode(codes, path; targetsize=targetsize, pixels=pixels, fps=fps)
end

end # module
