using QRCoders
using Test
using FileIO
using ImageCore
using Random

import QRCoders: makeblocks, geterrcorrblock, interleave, emptymatrix,
               characterscapacity, modeindicators, getcharactercountindicator,
               encodedata, ecblockinfo, padencodedmessage, makemasks, addformat,
               placedata!
import QRCoders.Polynomial: Poly, antilogtable, logtable, generator, iszeropoly,
                            rpadzeros, rstripzeros, gfpow2, gflog2, mult, divide,
                            zero, gfinv, unit, euclidean_divide, geterrorcorrection

randpoly(n::Int) = Poly([rand(0:255, n-1)..., rand(1:255)])
randpoly(range::AbstractVector{Int}) = randpoly(rand(range))

## test for operations
include("tst_operation.jl")

## original tests
include("tst_overall.jl")