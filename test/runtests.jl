using QRCoders
using Test
using FileIO
using ImageCore
using Random

using QRCoders: makeblocks, getecblock, interleave, emptymatrix, 
               characterscapacity, modeindicators, getcharactercountindicator,
               encodedata, ecblockinfo, padencodedmessage, makemasks, addformat,
               placedata!, bitarray2int, int2bitarray, kanji, charactercountlength,
               penalty, addformat, getmode, remainderbits, alphanumeric, antialphanumeric,
               kanji, antikanji
using QRCoders.Polynomial: Poly, antilogtable, logtable, generator, iszeropoly, degree,
                            rpadzeros, rstripzeros, gfpow2, gflog2, gfinv, mult, divide,
                            zero, unit, euclidean_divide, geterrorcorrection, init!, lead,
                            makelogtable

randpoly(n::Int) = Poly([rand(0:255, n-1)..., rand(1:255)])
randpoly(range::AbstractVector{Int}) = randpoly(rand(range))

## test for operations
include("tst_operation.jl")

## encode message
include("tst_encode.jl")

## build matrix
include("tst_build.jl")

## original tests
include("tst_overall.jl")