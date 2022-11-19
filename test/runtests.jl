using QRCoders
using Test
using FileIO
using Random
using ImageCore
using ImageTransformations
using TestImages
using StatsBase
using QRDecoders.Syndrome: fillerasures!

using QRCoders:
    # build
    makeblocks, getecblock, interleave, 
    emptymatrix, makemask, makemasks, penalty,
    placedata!, addformat!, addversion!,
    # tables
    alphanumeric, antialphanumeric, kanji, antikanji, 
    mode2bin, qrversion, qrformat, qrversionbits,
    ecblockinfo, remainderbits, msgbitslen,
    # encode
    getmode, characterscapacity, modeindicators, 
    getcharactercountindicator, charactercountlength,
    padencodedmessage, encodedata, encodemessage,
    # data convert
    bitarray2int, int2bitarray, bits2bytes,
    # style
    unicodeplot, getindexes, getsegments, getecinfo,
    # imagebyerrcor, animatebyerrcor,
    # pickcodewords,
    gauss_elimination, fillblank
                 
using QRCoders.Polynomial:
    # operator for GF(256) integers
    antipowtable, powtable, 
    gfpow2, gflog2, gfinv, mult, divide, powx,
    # operator for polynomials
    iszeropoly, degree, zero, unit,
    rpadzeros, rstripzeros, generator, 
    geterrcode, euclidean_divide,
    encodepoly

# random polynomial
randpoly(::Type{T}, n::Int) where T = Poly{T}([rand(0:255, n-1)..., rand(1:255)])
randpoly(n::Int) = randpoly(UInt8, n)
randpoly(::Type{T}, range::AbstractVector{Int}) where T = randpoly(T, rand(range))
randpoly(range::AbstractVector{Int}) = randpoly(UInt8, range)
imgpath = "testimages/"
eclevels = [Low(), Medium(), Quartile(), High()]
modes = [Numeric(), Alphanumeric(), Byte(), Kanji()]

# operations
include("tst_operation.jl")

# format and version information
include("tst_fmtver.jl")

# encode message
include("tst_encode.jl")

# struct QRCode
include("tst_construct.jl")

# original tests
include("tst_overall.jl")

# equations
include("tst_equation.jl")

# style
include("tst_style.jl")

# final message
unicodeplotbychar("https://github.com/JuliaImages/QRCoders.jl") |> println