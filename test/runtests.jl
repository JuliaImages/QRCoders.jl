using QRCoders
using Test
using FileIO
using ImageCore
using Random

using QRCoders:
    # build
    makeblocks, getecblock, interleave, 
    emptymatrix, makemask, makemasks, penalty,
    placedata!, addformat!, addversion!,
    # tables
    alphanumeric, antialphanumeric, kanji, antikanji, 
    mode2bin, qrversion, qrformat, qrversionbits,
    ecblockinfo, remainderbits,
    # encode
    getmode, characterscapacity, modeindicators, 
    getcharactercountindicator, charactercountlength,
    padencodedmessage, encodedata, encodemessage,
    # data convert
    bitarray2int, int2bitarray, bits2bytes
                 
using QRCoders.Polynomial:
    # operator for GF(256) integers
    makelogtable, antilogtable, logtable, 
    gfpow2, gflog2, gfinv, mult, divide,
    # operator for polynomials
    iszeropoly, degree, init!, lead, zero, unit,
    rpadzeros, rstripzeros, generator, 
    geterrorcorrection, euclidean_divide
                            
randpoly(n::Int) = Poly([rand(0:255, n-1)..., rand(1:255)])
randpoly(range::AbstractVector{Int}) = randpoly(rand(range))
imgpath = "testimages/"
eclevels = [Low(), Medium(), Quartile(), High()]

## operations
include("tst_operation.jl")

# format and version information
include("tst_fmtver.jl")

## encode message
include("tst_encode.jl")

## original tests
include("tst_overall.jl")