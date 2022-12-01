# Plot image inside QR code
"""
    imageinqrcode( code::QRCode
                 , img::AbstractMatrix{Bool}
                 ; rate::Real=1
                 , singlemask::Bool=true
                 , leftop::Tuple{Int, Int}=(-1, -1)
                 , fillaligment::Bool=false
                 ) where T <: Union{Bool, Nothing}

Plot image inside QR code.

## Arguments

  * `code::QRCode`: QR code
  * `img::AbstractMatrix{Bool}`: image to be plotted
  * `rate::Real=1`: damage rate of the error correction codewords
  * `singlemask::Bool=true`: use the default mask pattern
  * `leftop::Tuple{Int,Int}=(-1, -1)`: left top corner of the image
"""
function imageinqrcode( code::QRCode
                      , img::AbstractMatrix{T}
                      ; rate::Real=1
                      , singlemask::Bool=true
                      , leftop::Tuple{Int, Int}=(-1, -1)
                      , fillaligment::Bool=false
                      ) where T <: Union{Bool, Nothing}
    imageinqrcode!(copy(code), img; rate=rate, singlemask=singlemask, leftop=leftop, fillaligment=fillaligment)
end
function imageinqrcode!( code::QRCode
                       , img::AbstractMatrix{T}
                       ; rate::Real=1
                       , singlemask::Bool=true
                       , leftop::Tuple{Int,Int}=(-1, -1)
                       , fillaligment::Bool=false
                       ) where T <: Union{Bool, Nothing}
    ## 1. check input
    border, code.border = code.border, 0 # set border to 0
    (imgx, imgy), qrlen = size(img), qrwidth(code)
    qrlen ≥ max(imgx, imgy) || throw(ArgumentError("The image is too large."))
    rate ≥ 0 || throw(ArgumentError("The rate should be positive."))
    rate > 1 && @warn(ArgumentError(
        " It could risk to destroy the message if rate is bigger that 1."))
    
    ## 2. number of modified bytes for each block
    version, eclevel, mask = code.version, code.eclevel, code.mask
    necwords, nb1, nc1, nb2, nc2 = getecinfo(version, eclevel)
    modify = floor(Int, necwords * rate / 2)
    msglens = vcat(fill(nc1, nb1), fill(nc2, nb2))

    ## 3. plot image in canvas
    canvas = rand(Bool, qrlen, qrlen) # canvas = similar(stdmat)
    if leftop == (-1, -1) # plot in the center
        leftop = CartesianIndex((qrlen - imgx) >> 1, (qrlen - imgy) >> 1)
    else
        leftop = CartesianIndex(leftop)
    end
    imgI = findall((!isnothing).(img)) .+ Ref(leftop)
    setimgI = Set(imgI) # for fast search
    canvas[imgI] = img

    ## 4. get indexes of block bytes
    bytemsginds, byteecinds = getsegments(code)
    byteblockinds = [vcat(inds1, inds2) for (inds1, inds2) in zip(bytemsginds, byteecinds)]
    bitblockinds = [vcat(inds...) for inds in byteblockinds]

    ## 5. information of free blocks
    npureblock, nfreeblock, nfreebyte = getfreeinfo(code)
    # nfreebyte = 0 # set zero to skip the partial free block
    npurebyte = (npureblock ≥ nb1 ? nc2 : nc1) - nfreebyte # message bytes in the partial free block

    ## 6. sort bytes by the intersection area with the image
    sortbytes = [Vector{Int}(undef, msglens[npureblock + i]) for i in 1:nfreeblock+1]
    ### free blocks
    for i in 1:nfreeblock
        scores = count.(∈(setimgI), byteblockinds[npureblock + 1 + i])
        sortbytes[i+1] = sortindsample(scores, msglens[npureblock + 1 + i])
    end
    ### partial free block
    scores = @views count.(∈(setimgI), byteblockinds[npureblock + 1][npurebyte+1:end])
    sortbytes[1] = vcat(1:npurebyte, # the first `npurebyte`
        npurebyte .+ sortindsample(scores, msglens[npureblock + 1] - npurebyte)) # the rest

    # 7. find best values of the bit blocks
    masks = singlemask ? [mask] : [0:7;]
    bestmat, bestpenalty = nothing, Inf
    distance(mat) = @views sum(mat[imgI] == img)
    for mask in masks
        code.mask = mask
        stdmat = qrcode(code)
        _filldata!(stdmat, canvas, bitblockinds, byteblockinds, setimgI, sortbytes,
                   npureblock, nfreeblock, npurebyte, necwords, modify, mask, version)
        penalty = distance(stdmat)
        if penalty < bestpenalty
            bestmat, bestpenalty = stdmat, penalty
        end
    end
    # 8. fill alignment patterns
    if fillaligment
        rad = CartesianIndex(2, 2) # radius of alignment patterns
        centers = validaligment(version, setimgI)
        for c in centers
            inds = filter(∈(setimgI), Ref(c) .+ (-rad:rad))
            bestmat[inds] = canvas[inds]
        end
    end
    return addborder(bestmat, border)
end

"""
    getfreeinfo( msg::AbstractString
               , mode::Mode
               , eclevel::ErrCorrLevel
               , version::Int)

Return the number of free blocks and the number of bytes
of the partial-free block.

## Background
1. required bits
    requiredbits = mode indicator # 4 bits 
                + ccindicator(mode, version)
                + databits(msg, mode)
                + padbits # free bits(* important)
                = 8 * (nb1 * nc1 + nb2 * nc2)

2. messge block and error correction block
   - message blocks are splited from required bits
   - each msgblock is associated with an ecblock

3. message bits
    messagebits = msgblocks + ecblocks + remainder bits
"""
function getfreeinfo( msg::AbstractString
                    , mode::Mode
                    , eclevel::ErrCorrLevel
                    , version::Int)
    # number of blocks
    _, nb1, nc1, nb2, nc2 = getecinfo(version, eclevel)

    # length of non-padbits
    modelen = 4 # length of mode indicator
    i = (version ≥ 1) + (version ≥ 10) + (version ≥ 27)
    cclen = charactercountlength[mode][i] # length of character count bits
    datalen = length(encodedata(msg, mode)) # length of data bits
    nonpadbits = modelen + cclen + datalen
    # pad 0 to make the length of bits a multiple of 8
    mod8 = nonpadbits & 7
    if mod8 != 0
        nonpadbits += 8 - mod8
    end
    # length of required bits
    requiredlen = 8 * (nb1 * nc1 + nb2 * nc2)
    nonpadbits ≥ requiredlen && return nb1 + nb2 - 1, 0, 0 # no free/partial-free block

    # number of bytes of *real* message bits
    msgbyte = nonpadbits >> 3
    grp1 = nb1 * nc1 # number of bytes of group 1
    if msgbyte ≤ grp1
         # number of blocks of the message
        nmsgblock = ceil(Int, msgbyte / nc1)
        nfreeblock = nb2 + nb1 - nmsgblock
        nfreebyte = nc1 * nmsgblock - msgbyte
    else
        msgbyte -= grp1
        nmsgblock = ceil(Int, msgbyte / nc2)
        nfreeblock = nb2 - nmsgblock
        nfreebyte = nc2 * nmsgblock - msgbyte
        nmsgblock += nb1
    end
    npureblock = nmsgblock - 1
    return npureblock, nfreeblock, nfreebyte
end
getfreeinfo(code::QRCode) = getfreeinfo(code.message, code.mode, code.eclevel, code.version)

"""
    getimagescore(mat::AbstractMatrix{Bool}, img::AbstractMatrix{<:Bool})

Return the number of pixels that are different from the given matrix.

Note: the image should be plotted in the center.
"""
function getimagescore(mat::AbstractMatrix{Bool}, img::AbstractMatrix{<:Bool})
    qrlen = size(mat, 1)
    imgx, imgy = size(img)
    x1, y1 = 1 + (qrlen - imgx) >> 1, 1 + (qrlen - imgy) >> 1
    x2, y2 = x1 + imgx - 1, y1 + imgy - 1
    sum(mat[x1:x2, y1:y2] .!= img)
end

"""
    sortindsample(scores::AbstractVector, msglen::Int)

Return the indices of the sorted scores.

We pick random indexes when there are too many scores that
equals `8`. This can help decentralized the corrections.
"""
function sortindsample(scores::AbstractVector, msglen::Int)
    inds = sortperm(scores, rev=true)
    ind8 = findlast(==(8), scores[inds])
    if !isnothing(ind8) && ind8 > msglen 
        @views sample(inds[1:ind8], msglen; replace=false)
    else
        @view(inds[1:msglen])
    end
end

"""
    fitimgwidth(code::QRCode)

Return the fitted width of the image.
"""
fitimgwidth(code::QRCode) = qrwidth(code) - 2 * code.border - 14

"""
Fill data in the `stdmat` with the given datas. This function
is sperated from `imageinqrcode` to make it shorter.
"""
function _filldata!( stdmat::AbstractMatrix{Bool}
                   , canvas::AbstractMatrix
                   , bitblockinds::AbstractVector
                   , byteblockinds::AbstractVector
                   , setimgI::AbstractSet
                   , sortbytes::AbstractVector
                   , npureblock::Int
                   , nfreeblock::Int
                   , npurebyte::Int
                   , necwords::Int
                   , modify::Int
                   , mask::Int
                   , version::Int)
    # 1. initialize data
    bitblockvals = [Vector{Bool}(undef, length(inds)) for inds in bitblockinds]
    bitfreeblockvals = @view(bitblockvals[npureblock + 2:end])

    # 2. masked matrix
    maskmat = makemask(emptymatrix(version), mask)
    canvas .⊻= maskmat # apply mask to canvas

    # 3. pure message block -- read from standard QR matrix
    for i in 1:npureblock
        bitblockvals[i] = @view(stdmat[bitblockinds[i]])
    end

    # 4. free blocks -- fill blank
    for i in 1:nfreeblock
        # initialize
        bitinds, byteinds = bitblockinds[npureblock + 1 + i], byteblockinds[npureblock + 1 + i]
        validinds = sortbytes[i+1]
        # compute byte values
        bytevals = Vector{UInt8}(undef, length(byteinds))
        for j in validinds # read from canvas
            bytevals[j] = @views bitarray2int(canvas[byteinds[j]])
        end
        # fill the rest of bytes
        bytevals = fillblank(bytevals, validinds, necwords)
        # convert to bit values
        for (j, byte) in enumerate(bytevals)
            bitfreeblockvals[i][j * 8 - 7:j * 8] = int2bitarray(byte)
        end
        # apply mask
        bitfreeblockvals[i] .⊻= @view(maskmat[bitinds])
    end
    
    # 5. partial free block -- read from standard QR matrix + error correction
    ## initialize
    bitinds, byteinds = bitblockinds[npureblock + 1], byteblockinds[npureblock + 1]        
    validinds = sortbytes[1]
    bytevals = Vector{UInt8}(undef, length(byteinds))
    ## read from standard QR matrix
    for i in 1:npurebyte
        # remove mask
        bits = @views stdmat[byteinds[i]] .⊻ maskmat[byteinds[i]]
        bytevals[i] = bitarray2int(bits)
    end
    ## read from canvas
    for i in @views validinds[npurebyte+1:end]
        bytevals[i] = @views bitarray2int(canvas[byteinds[i]])
    end
    ## fill the rest of bytes
    bytevals = fillblank(bytevals, validinds, necwords)
    for (i, byte) in enumerate(bytevals)
        bitblockvals[npureblock + 1][i * 8 - 7:i * 8] = int2bitarray(byte)
    end
    bitblockvals[npureblock + 1] .⊻= @view(maskmat[bitinds])
    for (inds, vals) in zip(bitblockinds, bitblockvals)
        stdmat[inds] = vals
    end

    ## 6. error correction
    canvas .⊻= maskmat # remove the mask
    bytecost(byte) = count(ind->stdmat[ind] != canvas[ind], filter(∈(setimgI), byte))
    for block in byteblockinds
        modify == 0 && break # no need to modify
        scores = bytecost.(block)
        sortinds = sortindsample(scores, modify)
        errind = @views findlast(!iszero, scores[sortinds])
        isnothing(errind) && continue
        for byte in @views block[sortinds[1:errind]]
            byte = filter(∈(setimgI), byte)
            stdmat[byte] = @view(canvas[byte])
        end
    end
    return stdmat
end