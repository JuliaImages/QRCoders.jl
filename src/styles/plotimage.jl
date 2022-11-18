# 3. Plot image inside QR code
## 3.1 use error correction

"""
    pickindexes(errinds::AbstractVector{<:Integer}, blockinds{<:Integer}, modify::Int)

Pick indexes from `blockinds` by `errinds`. The number of codewords that will be 
modified is `modify`. Here 1 codeword = 8 bits.
"""
function pickcodewords( errinds::AbstractVector{<:Integer}
                      , validbytes::AbstractVector{<:AbstractVector}
                      , modify::Int)
    ## locate codewords
    blocklen = length(validbytes)
    modify ≥ blocklen && return validbytes
    errinds = Set(errinds) # for fast searching
    damages = [count(in(errinds), bytes) for bytes in validbytes]
    ## sort by damage cost
    inds = @views sort(1:blocklen, by=i->damages[i], rev=true)[1:modify]
    # inds = @views inds[1:count(!iszero, damages)] # discard the correct bits
    @views validbytes[inds]
end

function pack2bytes(inds::AbstractVector{<:Integer})
    n = length(inds)
    return [inds[i:i+7] for i in 1:8:n & 7 ⊻ n] # discard remainder bits
end

"""
    imagebyerrcor(code::QRCode, targetmat::AbstractMatrix, rate::Real=2/3)

Plot the image `targetmat` inside the QR code using error correction.

In order to get the best simulation, the error correction level
is recommended to be `High()`.

The parameter `rate` is the rate of the error correction codewords
that will be modified. The default value is `2/3`, which means that
`1/2 * 2/3 = 1/3` of the error correction codewords will be modified.
"""
imagebyerrcor(code::QRCode, targtemat::AbstractMatrix; rate::Real=2/3) = imagebyerrcor!(copy(code), targtemat; rate=rate)

function imagebyerrcor!( code::QRCode
                       , targetmat::AbstractMatrix
                       ; rate::Real=2/3)
    ## check parameters
    rate ≥ 0 || throw(ArgumentError("rate should be non-negative."))
    rate ≤ 1 || @warn(ArgumentError("Invalid rate $rate." *
            " It could risk to destroy the message if rate is bigger that 1."))
    border, code.border = code.border, 0 # reset border -- compat to indexes rule
    (imgx, imgy), qrlen = size(targetmat), qrwidth(code)
    qrlen ≥ max(imgx, imgy) || throw(ArgumentError("The image is too large."))
    
    ## image position
    x1, y1 = (qrlen - imgx + 1) >> 1, (qrlen - imgy + 1) >> 1
    x2, y2 = x1 + imgx - 1, y1 + imgy - 1
    function isvalid(p::Int)
        x, y = p % qrlen, p ÷ qrlen
        x1 ≤ x ≤ x2 && y1 ≤ y ≤ y2
    end  

    ## locations of message bits
    version, eclevel = code.version, code.eclevel
    msginds, ecinds = getsegments(version, eclevel)
    # number of error correction codewords
    necwords = length(first(ecinds)) >> 3
    modify = floor(Int, necwords * rate / 2)

    # valid indexes
    validmsgecinds = [vcat(inds1, inds2) for (inds1, inds2) in zip(msginds, ecinds)]
    validbytes = [filter!.(isvalid, pack2bytes(inds)) for inds in validmsgecinds]
    filter!.(isvalid, validmsgecinds) # filter out invalid indexes
    validinds = vcat(validmsgecinds...)
    # indexes inside the image
    targetval(ind::Int) = targetmat[ind % qrlen - x1 + 1, ind ÷ qrlen - y1 + 1]
      
    ## cost function
    penalty(newmat) = sum(newmat[validinds] .== targetval.(validinds))
    ## enumerate over masks
    bestmat, bestpenalty = nothing, Inf
    for mask in 0:7
        code.mask = mask
        newmat = qrcode(code)
        for (vinds, vbytes) in zip(validmsgecinds, validbytes) # enumerate over each blcok
            errinds = filter(x -> newmat[x] != targetval(x), vinds)
            bytes = pickcodewords(errinds, vbytes, modify)
            @inbounds for inds in bytes
                newmat[inds] = targetval.(inds)
            end
        end
        newpenalty = penalty(newmat)
        if newpenalty < bestpenalty
            bestmat, bestpenalty = newmat, newpenalty
        end
    end
    # add white border
    return addborder(bestmat, border)
end

"""
    imagebyerrcor( message::AbstractString
                , targetmat::AbstractMatrix
                ; version::Int=16
                , mode::Mode=Numeric()
                , eclevel::ErrCorrLevel=High()
                , width::Int=2
                , rate::Real=2/3)

Plot the image inside the QR code of `message` using error correction.
"""
function imagebyerrcor( message::AbstractString
                      , targetmat::AbstractMatrix
                      ; version::Int=16
                      , mode::Mode=Numeric()
                      , eclevel::ErrCorrLevel=High()
                      , width::Int=0
                      , rate::Real=2/3)
    code = QRCode(message, version=version, eclevel=eclevel, mode=mode, width=width)
    return imagebyerrcor!(code, targetmat, rate=rate)
end

"""
    animatebyerrcor( codes::AbstractVector{QRCode}
                   , targetmats::AbstractVector{<:AbstractMatrix}
                   ; rate::Real=2/3
                   , pixels::Int=160
                   , fps::Int=10
                   , filename::AbstractString="animate.gif")

Plot the image inside the QR code of `message` using error correction,
and save the animation to `filename`.
"""
function animatebyerrcor( codes::AbstractVector{QRCode}
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
    @inbounds for (i, code) in enumerate(codes)
        mat = imagebyerrcor(code, targetmats[i], rate=rate)
        animate[:, :, i] = _resize(mat, pixels)
    end
    save(filename, .! animate, fps=fps)
end