using QRCoders
using Test
using FileIO
using ImageCore
using Random

import QRCoders: makeblocks, geterrcorrblock, interleave, emptymatrix,
               characterscapacity, modeindicators, getcharactercountindicator,
               encodedata, ecblockinfo, padencodedmessage, makemasks, addformat,
               placedata!, bitarray2int, int2bitarray
import QRCoders.Polynomial: Poly, antilogtable, logtable, generator, iszeropoly, degree,
                            rpadzeros, rstripzeros, gfpow2, gflog2, gfinv, mult, divide,
                            zero, unit, euclidean_divide, geterrorcorrection

randpoly(n::Int) = Poly([rand(0:255, n-1)..., rand(1:255)])
randpoly(range::AbstractVector{Int}) = randpoly(rand(range))

## test for operations
include("tst_operation.jl")

## original tests
include("tst_overall.jl")