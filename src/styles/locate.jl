# Locate message bits

## extract indexes of message bits

"""
    getindexes(v::Int)

Extract indexes of message bits from the QR code of version `v`.

Note: The procedure is similar to `placedata!` in `matrix.jl`.
"""
function getindexes(v::Int)
    mat, n = emptymatrix(v), 17 + 4 * v
    inds = Vector{CartesianIndex{2}}(undef, msgbitslen[v])
    col, row, ind = n, n + 1, 1
    while col > 0
        # Skip the column with the timing pattern
        if col == 7
            col -= 1
            continue
        end
        # path goes up and down
        row, δrow = row > n ? (n, -1) : (1, 1)
        # recode index if the matrix element is nothing
        for _ in 1:n
            if isnothing(mat[row, col])
                inds[ind] = CartesianIndex(row, col)
                ind += 1
            end
            if isnothing(mat[row, col - 1])
                inds[ind] = CartesianIndex(row, col - 1)
                ind += 1
            end
            row += δrow
        end
        # move to the next column
        col -= 2
    end
    ind == msgbitslen[v] + 1 || throw(ArgumentError(
        "The number of indexes is not correct."))
    return inds
end
getindexes(code::QRCode) = getindexes(code.version)

## split indexes into several segments(de-interleave)
"""
    getecinfo(v::Int, eclevel::ErrCorrLevel)

Get the error correction information.
"""
getecinfo(v::Int, eclevel::ErrCorrLevel) = @views ecblockinfo[eclevel][v, :]
getecinfo(code::QRCode) = getecinfo(code.version, code.eclevel)

"""
    getsegments(code::QRCode)

Get indexes segments of the QR code.

Note: The procedure is similar to `deinterleave` in `QRDecoders.jl`.
"""
getsegments(code::QRCode) = getsegments(code.version, code.eclevel)
function getsegments(v::Int, eclevel::ErrCorrLevel)
    # initialize
    ## get information about error correction
    necwords, nb1, nc1, nb2, nc2 = getecinfo(v, eclevel)
    ## initialize blocks
    segments = vcat([Vector{Vector{CartesianIndex{2}}}(undef, nc1) for _ in 1:nb1],
                    [Vector{Vector{CartesianIndex{2}}}(undef, nc2) for _ in 1:nb2])
    ecsegments = [Vector{Vector{CartesianIndex{2}}}(undef, necwords) for _ in 1:nb1 + nb2]
    # get segments from the QR code
    ## indexes of message bits
    inds = getindexes(v)
    ## discard remainder bits
    inds = @view inds[1:end-remainderbits[v]]
    length(inds) & 7 == 0 || throw(ArgumentError(
        "The number of indexes is not correct."))
    
    ## get blocks
    ind = length(inds) >> 3 # number of bytes
    ### error correction bytes
    @inbounds for i in necwords:-1:1, j in (nb1 + nb2):-1:1
        ecsegments[j][i] = @view(inds[ind * 8 - 7:ind * 8])
        ind -= 1
    end
    ### message bytes
    @inbounds for i in nc2:-1:(1 + nc1), j in (nb1 + nb2):-1:(nb1 + 1)
        segments[j][i] = @view(inds[ind * 8 - 7:ind * 8])
        ind -= 1
    end
    @inbounds for i in nc1:-1:1, j in (nb1 + nb2):-1:1
        segments[j][i] = @view(inds[ind * 8 - 7:ind * 8])
        ind -= 1
    end
    ind != 0 && throw(ArgumentError("getsegments: not all data is recorded"))
    return segments, ecsegments
end

"""
    validalignment(v::Int, imgx::Int, imgy::Int)

Return the position of alignment pattern that has intersection
with the image.
"""
function validalignment(v::Int, imgI::AbstractSet)
    # version 1 does not have alignment pattern
    v == 1 && return Tuple{Int, Int}[]
    # skip the alignment pattern that has intersection with the time pattern
    aligns = filter(>(6), alignmentlocation[v]) .+ 1 # off set 1
    # keep the alignment pattern that has intersection with the image
    [CartesianIndex(x, y) for x in aligns for y in aligns if CartesianIndex(x, y) in imgI]
end

"""
    getversioninds(v::Int)

Get indexes of the version information.
"""
function getversioninds(v::Int)
    # version ≤ 6 does not have version information
    v ≤ 6 && throw(ArgumentError("The version $v should be larger than 6."))
    # get indexes of the version information
    n = 17 + 4 * v
    vcat([CartesianIndex(i, j) for j in 1:6 for i in n - 10:n-8], # left bottom
         [CartesianIndex(i, j) for i in 1:6 for j in n - 10:n-8]) # right top
end
getversioninds(code::QRCode) = getversioninds(code.version)

"""
    getformatinds(v::Int)

Get indexes of the format information.
"""
function getformatinds(v::Int)
    n = 17 + 4 * v
    return vcat([CartesianIndex(9, i) for i in [1:6;8]],
                [CartesianIndex(i, 9) for i in [9,8,6:-1:1...]],
                [CartesianIndex(i, 9) for i in n:-1:n-6],
                [CartesianIndex(9, i) for i in n-7:n])
end
getformatinds(code::QRCode) = getformatinds(code.version)

"""
    gettiminginds(v::Int)

Get indexes of the timing pattern.
"""
function gettiminginds(v::Int)
    n = 17 + 4 * v
    return vcat([CartesianIndex(i, 7) for i in 8:n-7],
                [CartesianIndex(7, i) for i in 8:n-7])
end
gettiminginds(code::QRCode) = gettiminginds(code.version)

"""
    getdarkindex(v::Int)

Get the index of the dark module.
"""
function getdarkindex(v::Int)
    n = 17 + 4 * v
    return CartesianIndex(n-7, 9)
end
getdarkindex(code::QRCode) = getdarkindex(code.version)

"""
    getalignmentinds(v::Int)

Get the left-top indexes of alignment patterns.
"""
function getalignmentinds(v::Int)
    # version 1 does not have alignment pattern
    v == 1 && return CartesianIndex{2}[]
    n = 17 + 4 * v
    # get indexes of the alignment pattern
    aligns = alignmentlocation[v]
    algpos = Vector{CartesianIndex{2}}(undef, length(aligns)^2 - 3)
    ind = 1
    for i in aligns, j in aligns
        if !( (i < 9 && j < 9)   ||
              (i < 9 && j > n - 10) ||
              (i > n - 10 && j < 9) )
            algpos[ind] = CartesianIndex(i-1, j-1)
            ind += 1
        end
    end
    return algpos
end
getalignmentinds(code::QRCode) = getalignmentinds(code.version)

"""
    getfinderinds(v::Int)

Get the left-top indexes of finder patterns.
"""
function getfinderinds(v::Int)
    n = 17 + 4 * v
    return [CartesianIndex(1, 1), 
            CartesianIndex(n-6, 1),
            CartesianIndex(1, n-6)]
end
getfinderinds(code::QRCode) = getfinderinds(code.version)

"""
    getsepinds(v::Int)

Get the indexes of the seperators.
"""
function getsepinds(v::Int)
    n = 17 + 4 * v
    vcat(# left top
        CartesianIndex.(1:8, 8),
        CartesianIndex.(8, 1:8), 
        # left down
        CartesianIndex.(n-7, 1:8),
        CartesianIndex.(8, n-7:n), 
        # right top        
        CartesianIndex.(n-7:n, 8),
        CartesianIndex.(1:8, n-7))
end
getsepinds(code::QRCode) = getsepinds(code.version)