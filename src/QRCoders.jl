"""
Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.
"""
module QRCoders

using ImageCore
using FileIO
using UnicodePlots
using StatsBase

export
    # create QR code
    qrcode, exportqrcode, QRCode,
    exportbitmat, addborder,
    # supported modes
    Mode, Numeric, Alphanumeric, Byte, Kanji, UTF8,
    # error correction levels
    ErrCorrLevel, Low, Medium, Quartile, High,
    # get information about QR code
    getmode, getversion, qrwidth, 
    getindexes, getsegments, getdarkindex,
    getalignmentinds, getfinderinds,
    # polynomial operations
    Poly, geterrcode, generator_matrix,
    # error type
    EncodeError,
    # locate QR matrix
    validalignment, getversioninds,
    getformatinds, gettiminginds, getsepinds,
    # QR code style
    unicodeplot, unicodeplotbychar, fitimgwidth,
    imageinqrcode, getfreeinfo, getimagescore
# Data types in QRCoders
include("types.jl")

# Data tables from the specificatioms
include("preprocess/tables.jl")

# Polynomial arithmetic
include("polynomial.jl")
using .Polynomial

# Manipulations for creating the QR code matrix
include("preprocess/matrix.jl")

# Encoding process
include("encode.jl")

# Special QR codes
include("styles/style.jl")

# Generate and export QR code
include("export.jl")

end # module
