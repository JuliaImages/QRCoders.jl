# Data types in QRCoders

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

# structure type of the QR code
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
    copy(code::QRCode)

Returns a copy of `code`.
"""
function Base.copy(code::QRCode)
    QRCode(code.version, code.mode, code.eclevel, 
           code.mask, code.message, code.border)
end


"""
    QRCode( message::AbstractString
          ; mask::Int = -1
          , eclevel::ErrCorrLevel = Medium()
          , mode::Mode = Numeric()
          , version::Int = 0
          , width::Int = 1)

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
Base.show(io::IO, code::QRCode) = print(io, unicodeplotbychar(qrcode(code)))