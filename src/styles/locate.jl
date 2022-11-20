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