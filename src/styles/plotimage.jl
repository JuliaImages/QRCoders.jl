#= Plot image inside QR code
Set value of mask from 0 to 7.


=#

"""
    imageinqrcode(code::QRCode, img::AbstractMatrix, rate::Real=1)

Plot image inside QR code.
"""
function imageinqrcode( code::QRCode
                      , img::AbstractMatrix
                      ; rate::Real=1
                      , singlemask=true)
    # ---- preprocess ---- #
        ## 1.1 check input
        code.border == 0 || throw(ArgumentError("Border of the QR code should be 0"))
        (imgx, imgy), qrlen = size(img), qrwidth(code)
        qrlen ≥ max(imgx, imgy) || throw(ArgumentError("The image is too large."))
        rate ≥ 0 || throw(ArgumentError("The rate should be positive."))
        rate > 1 && @warn(ArgumentError(
            " It could risk to destroy the message if rate is bigger that 1."))
        
        ## 1.2 number of modified bytes for each block
        version, eclevel, mask = code.version, code.eclevel, code.mask
        necwords, nb1, nc1, _, nc2 = getecinfo(version, eclevel)
        modify = floor(Int, necwords * rate / 2)

        ## 1.3 standard QR matrix and masked matrix
        stdmat = qrcode(code) # standard QR code
        maskmat = makemask(emptymatrix(version), mask)
        canvas = rand(Bool, qrlen, qrlen) # canvas = similar(stdmat)

        ## 1.4 plot image in canvas
        x1, y1 = (qrlen - imgx + 1) >> 1, (qrlen - imgy + 1) >> 1
        x2, y2 = x1 + imgx - 1, y1 + imgy - 1
        imgI = CartesianIndices((x1:x2, y1:y2))
        canvas[imgI] = img
        canvas .⊻= maskmat

        ## 1.5 get indexes of block bytes
        bytemsginds, byteecinds = getsegments(code)
        byteblockinds = [vcat(inds1, inds2) for (inds1, inds2) in zip(bytemsginds, byteecinds)]
        bitblockinds = [vcat(inds...) for inds in byteblockinds]

        ## 1.6 information of free blocks
        npureblock, nfreeblock, nfreebyte = getfreeinfo(code)
        npurebyte = (npureblock > nb1 ? nc2 : nc1) - nfreebyte # number of message bytes in the partial free block
        bytefreeblockinds = @view(byteblockinds[npureblock + 2:end])
        bitfreeblockinds = @view(bitblockinds[npureblock + 2:end])

    # ----- compute values of the bit blocks ----- #
        ## 2.1 allocations
        bitblockvals = [Vector{Bool}(undef, length(inds)) for inds in bitblockinds]
        bitfreeblockvals = @view(bitblockvals[npureblock + 2:end])

        ## 2.2 pure message block -- read from standard QR matrix
        for i in 1:npureblock
            bitblockvals[i] = @view(stdmat[bitblockinds[i]])
        end

        ## 2.3 free blocks -- error correction
        ### sort bytes by the intersection area with the image
        sortbytes = [sortperm(count.(∈(imgI), bytefreeblockinds[i]), rev=true) for i in 1:nfreeblock]
        ### error correction
        for i in 1:nfreeblock
            bitvals = bitfreeblockvals[i] # **our target**
            bitinds, byteinds = bitfreeblockinds[i], bytefreeblockinds[i]
            sortinds = sortbytes[i]
            reclen = length(byteinds) # length of the received message
            msglen = reclen - necwords
            validinds = @views sortinds[1:msglen]
            # initialize byte values
            bytevals = Vector{UInt8}(undef, reclen)
            for j in validinds # read from canvas
                bytevals[j] = @views bitarray2int(canvas[byteinds[j]])
            end
            # fill the rest of bytes
            bytevals = fillblank(bytevals, validinds, necwords)
            # convert to bit values
            for (i, byte) in enumerate(bytevals)
                bitvals[i * 8 - 7:i * 8] = int2bitarray(byte)
            end
            # apply mask
            bitvals .⊻= @view(maskmat[bitinds])
        end
        
        ## 2.4 partial free block -- read from standard QR matrix + error correction
        ### our target: `bitvals`
        bitvals = bitblockvals[npureblock + 1]
        bitinds, byteinds = bitblockinds[npureblock + 1], byteblockinds[npureblock + 1]
        ### sort bytes by the intersection area with the image
        scores = @views count.(∈(imgI), byteinds[npurebyte+1:end])
        sortinds = vcat(1:npurebyte, # the first `npurebyte`
            npurebyte .+ sortperm(scores, rev=true))
        ### error correction
        reclen = length(byteinds) # length of the received message
        msglen = reclen - necwords
        validinds = @views sortinds[1:msglen]
        #### initialize byte values
        bytevals = Vector{UInt8}(undef, reclen)
        for i in 1:npurebyte # read from standard QR matrix
            # remove mask
            bits = @views stdmat[byteinds[i]] .⊻ maskmat[byteinds[i]]
            bytevals[i] = bitarray2int(bits)
        end
        for i in @views sortinds[npurebyte+1:msglen] # read from canvas
            bytevals[i] = @views bitarray2int(canvas[byteinds[i]])
        end
        #### fill the rest of bytes
        bytevals = fillblank(bytevals, validinds, necwords)
        #### convert to bit values
        for (i, byte) in enumerate(bytevals)
            bitvals[i * 8 - 7:i * 8] = int2bitarray(byte)
        end
        #### apply mask
        bitvals .⊻= @view(maskmat[bitinds])
    
    # ----- fill in by the modified bits ----- #
    for (inds, vals) in zip(bitblockinds, bitblockvals)
        stdmat[inds] = vals
    end
    # ----- return the modified QR code ----- #
    canvas .⊻= maskmat # remove the mask
    bytecost(byte) = count(ind->stdmat[ind] != canvas[ind], filter(∈(imgI), byte))
    for block in byteblockinds
        sortinds = sortperm(bytecost.(block), rev=true)
        for byte in @views block[sortinds[1:modify]]
            stdmat[byte] = @view(canvas[byte])
        end
    end
    return stdmat
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
    nonpadbits ≥ requiredlen && return 0, 0 # no free/partial-free block

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
    end
    npureblock = nmsgblock - 1
    return npureblock, nfreeblock, nfreebyte
end
getfreeinfo(code::QRCode) = getfreeinfo(code.message, code.mode, code.eclevel, code.version)