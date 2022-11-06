# special QR codes
## supported list
## 1. Unicode plot
### I. Unicode plot by UnicodePlots.jl
### II. Unicode plot by Unicode characters
## 2. plot image in QR code
### 2.1 extract indexes of message bits
### 2.2 split indexes into several segments(de-interleave)

# 1. Unicode plot
"""
    unicodeplot(mat::AbstractMatrix{Bool}; border=:none)

Uses UnicodePlots.jl to draw the matrix.

Note: In UnicodePlots.jl, matrix index start from the left-down corner.
"""
function unicodeplot(mat::AbstractMatrix{Bool}; border=:none)
    width, height = size(mat)
    return heatmap(@view(mat[end:-1:1,:]);
                  labels=false, 
                  border=border, 
                  colormap=:gray,
                  width=width,
                  height=height)
end

"""
    unicodeplot(message::AbstractString
              ; border=:none)

Uses UnicodePlots.jl to draw the QR code of `message`.
"""
function unicodeplot(message::AbstractString; border=:none)
    unicodeplot(qrcode(message;eclevel=Low(), width=2); border=border) 
end

## idea by @notinaboat
const pixelchars = [' ', '▄', '▀', '█']
pixelchar(block::AbstractVector) = pixelchars[2 * block[1] + block[2] + 1]
pixelchar(bit::Bool) = pixelchars[1 + 2 * bit]

"""
    unicodeplotbychar(mat::AbstractMatrix)

Plot of the QR code using Unicode characters.

Note that `true` represents white and `false` represents black.
"""
function unicodeplotbychar(mat::AbstractMatrix)
    m = size(mat, 1)
    txt = @views join((join(pixelchar.(eachcol(mat[i:i+1, :]))) for i in 1:2:m & 1 ⊻ m), '\n')
    isodd(m) || return txt
    return @views txt * '\n' * join(pixelchar.(mat[m, :]))
end

"""
    unicodeplotbychar(message::AbstractString)

Plot of the QR code using Unicode characters.

Note that `true` represents black and `false` represents white in qrcode, 
which is the opposite of the image convention.
"""
function unicodeplotbychar(message::AbstractString)
    unicodeplotbychar(.! qrcode(message; eclevel=Low(), width=2))
end

# 2. plot image in QR code
## 2.1 extract indexes of message bits

"""
    getindexes(v::Int)

Extract indexes of message bits from the QR code of version `v`.

The procedure is similar to `placedata!` in `matrix.jl`.
"""
function getindexes(v::Int)
    mat, n = emptymatrix(v), 17 + 4 * v
    inds = Vector{Int}(undef, msgbitslen[v])
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
                inds[ind] = (col - 1) * n + row
                ind += 1
            end
            if isnothing(mat[row, col - 1])
                inds[ind] = (col - 2) * n + row
                ind += 1
            end
            row += δrow
        end
        # move to the next column
        col -= 2
    end
    ind == length(inds) + 1 || throw(ArgumentError(
        "The number of indexes is not correct."))
    return inds
end

## 2.2 split indexes into several segments(de-interleave)

"""
    getsegments(v::Int, mode::Mode, eclevel::ErrCorrLevel)

Get indexes segments of the corresponding settings.
Each of the segments has atmost 8 * 255 elements.

The procedure is similar to `deinterleave` in `QRDecoders.jl`.
"""
function getsegments(v::Int, eclevel::ErrCorrLevel)
    # initialize
    ## get information about error correction
    ncodewords, nb1, nc1, nb2, nc2 = ecblockinfo[eclevel][v, :]
    ## initialize blocks
    blocks = vcat([Vector{Int}(undef, nc1) for _ in 1:nb1],
                    [Vector{Int}(undef, nc2) for _ in 1:nb2])
    ecblocks = [Vector{Int}(undef, ncodewords) for _ in 1:nb1 + nb2]

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
    for i in ncodewords:-1:1, j in (nb1 + nb2):-1:1
        ecblocks[j][i] = ind
        ind -= 1
    end
    ### message bytes
    for i in nc2:-1:(1 + nc1), j in (nb1 + nb2):-1:(nb1 + 1)
        blocks[j][i] = ind
        ind -= 1
    end
    for i in nc1:-1:1, j in (nb1 + nb2):-1:1
        blocks[j][i] = ind
        ind -= 1
    end
    ind != 0 && throw(ArgumentError("getsegments: not all data is recorded"))

    ## expand blocks to get segments
    expand(x) = (8 * x - 7):8 * x
    segments = [inds[vcat(expand.(block)...)] for block in blocks]
    ecsegments = [inds[vcat(expand.(block)...)] for block in ecblocks]
    return segments, ecsegments
end