#=
# special QR codes
supported list:
    1. Unicode plot
        I. Unicode plot by UnicodePlots.jl
        II. Unicode plot by Unicode characters
    2. locate message bits
        2.1 extract indexes of message bits
        2.2 split indexes into several segments(de-interleave)
    3. plot image inside QR code
        I. use error correction
        II. use remainder bits
        III. use remainder bits and error correction
=#

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

# 2. locate message bits
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
    expand(x) = (8 * x - 7):8 * x
    segments = vcat([Vector{Int}(undef, 8 * nc1) for _ in 1:nb1],
                    [Vector{Int}(undef, 8 * nc2) for _ in 1:nb2])
    ecsegments = [Vector{Int}(undef, 8 * ncodewords) for _ in 1:nb1 + nb2]
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
        ecsegments[j][expand(i)] = @view(inds[expand(ind)])
        ind -= 1
    end
    ### message bytes
    for i in nc2:-1:(1 + nc1), j in (nb1 + nb2):-1:(nb1 + 1)
        segments[j][expand(i)] = @view(inds[expand(ind)])
        ind -= 1
    end
    for i in nc1:-1:1, j in (nb1 + nb2):-1:1
        segments[j][expand(i)] = @view(inds[expand(ind)])
        ind -= 1
    end
    ind != 0 && throw(ArgumentError("getsegments: not all data is recorded"))
    return segments, ecsegments
end

## 3. plot image inside QR code
### I. use error correction

"""
    pickindexes(errinds::AbstractVector{<:Integer}, blockinds{<:Integer}, destroy::Int)

Pick indexes from `blockinds` by `errinds`. The number of codewords that will be 
destroyed is `destroy`. Here 1 codeword = 8 bits.
"""
function pickcodewords( errinds::AbstractVector{<:Integer}
                      , blockinds::AbstractVector{<:Integer}
                      , destroy::Int)
    ## locate codewords
    length(blockinds) & 7 == 0 || throw(ArgumentError(
        "The number of indexes is not correct."))
    blocklen = length(blockinds) >> 3
    damges = zeros(Int, blocklen)
    errinds = Set(errinds) # for fast searching
    for i in 1:blocklen
        damges[i] = @views count(in(errinds), blockinds[8 * i - 7:8 * i])
    end
    ## sort by damage cost
    inds = @views sort(1:blocklen, by=i->damges[i], rev=true)[1:destroy]
    ## recover the codewords
    @views vcat([blockinds[8 * i - 7:8 * i] for i in inds]...)
end

"""
    imageinqrcode(code::QRCode, targetmat::AbstractMatrix, rate::Real=2/3)

Plot the image `targetmat` inside the QR code.

In order to get the best simulation, the error correction level
is recommended to be `High()`.

The parameter `rate` is the rate of the error correction codewords
that will be destroyed. The default value is `2/3`, which means that
`1/2 * 2/3 = 1/3` of the error correction codewords will be destroyed.
"""
imageinqrcode(code::QRCode, targtemat::AbstractMatrix; rate::Real=2/3) = imageinqrcode!(copy(code), targtemat; rate=rate)

function imageinqrcode!( code::QRCode
                       , targetmat::AbstractMatrix
                       ; rate::Real=2/3)
    ## check parameters
    0 ≤ rate ≤ 1 || throw(ArgumentError("Invalid rate $rate." *
            " It could risk to destroy the message if rate is bigger that 1."))
    border, code.border = code.border, 0 # reset border -- compat to indexes rule
    (imgx, imgy), qrlen = size(targetmat), qrwidth(code)
    version, eclevel = code.version, code.eclevel
    qrlen ≥ max(imgx, imgy) || throw(ArgumentError("The image is too large."))
    
    ## image position
    x1, y1 = (qrlen - imgx + 1) >> 1, (qrlen - imgy + 1) >> 1
    x2, y2 = x1 + imgx - 1, y1 + imgy - 1
    leftop = (x1 - 1, y1 - 1)

    ## locations of message bits
    msginds, ecinds = getsegments(version, eclevel)
    msgecinds = [vcat(inds1, inds2) for (inds1, inds2) in zip(msginds, ecinds)]
    # number of error correction codewords
    ncodewords = length(first(ecinds)) >> 3
    destroy = floor(Int, ncodewords * rate / 2)
    # indexes inside the image
    ind2point(ind::Int) = (ind % qrlen, ind ÷ qrlen)
    targetval(ind::Int) = targetmat[(ind2point(ind) .- leftop)...]
    function isvalid(p::Int)
         x, y = ind2point(p)
         x1 ≤ x ≤ x2 && y1 ≤ y ≤ y2
    end
    validinds = vcat(filter!.(isvalid, msginds)...,
                     filter!.(isvalid, ecinds)...)
    ## cost function
    penalty(newmat) = count(ind->newmat[ind] != targetval(ind), validinds)

    ## enumerate over masks
    bestmat, bestpenalty = nothing, Inf
    for mask in 0:7
        code.mask = mask
        newmat = qrcode(code)
        for blockinds in msgecinds # enumerate over each blcok
            errinds = filter(x -> isvalid(x) && newmat[x] != targetval(x), blockinds)
            inds = filter!(isvalid, pickcodewords(errinds, blockinds, destroy))
            newmat[inds] = targetval.(inds)
        end
        newpenalty = penalty(newmat)
        if newpenalty < bestpenalty
            bestmat, bestpenalty = newmat, newpenalty
        end
    end
    # add white border
    background = falses(size(bestmat) .+ (border*2, border*2))
    background[border+1:end-border, border+1:end-border] = bestmat
    return background
end

"""
    imageinqrcode( message::AbstractString
                , targetmat::AbstractMatrix
                ; version::Int=16
                , mode::Mode=Numeric()
                , eclevel::ErrCorrLevel=High()
                , width::Int=2
                , rate::Real=2/3)

Plot the image inside the QR code of `message`.
"""
function imageinqrcode( message::AbstractString
                      , targetmat::AbstractMatrix
                      ; version::Int=16
                      , mode::Mode=Numeric()
                      , eclevel::ErrCorrLevel = High()
                      , width::Int=0
                      , rate::Real=2/3)
    code = QRCode(message, version=version, eclevel=eclevel, mode=mode, width=width)
    return imageinqrcode!(code, targetmat, rate=rate)
end

"""
    animatebyqrcode( codes::AbstractVector{QRCode}
                    , targetmats::AbstractVector{<:AbstractMatrix}
                    ; rate::Real=2/3
                    , pixels::Int=160
                    , fps::Int=10
                    , filename::AbstractString="animate.gif")

Plot the image inside the QR code of `message` and save the animation
to `filename`.
"""
function animatebyqrcode( codes::AbstractVector{QRCode}
                        , targetmats::Vector{<:AbstractArray}
                        , filename::AbstractString="animate.gif"
                        ; rate::Real=2/3
                        , pixels::Int=160
                        , fps::Int=5)
    width = qrwidth(first(codes))
    all(==(width), qrwidth.(codes)) || throw(ArgumentError(
        "All QR codes should have the same version."))
    length(codes) == length(targetmats) || throw(ArgumentError(
        "The number of QR codes should be equal to the number of target images."))
    
    pixels = ceil(Int, pixels / width) * width
    animate = Array{Bool}(undef, pixels, pixels, length(codes))
    for (i, code) in enumerate(codes)
        mat = imageinqrcode(code, targetmats[i], rate=rate)
        animate[:, :, i] = _resize(mat, pixels)
    end
    save(filename, .! animate, fps=fps)
end

### II. plot using remainder bits