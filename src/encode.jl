# encode message into bit array
## outline
### 1. mode, indicator and message bits
### 2. make blocks with error-correction bits
### 3. interleave the blocks

using .Polynomial: Poly, geterrcode

"""
    utf8len(message::AbstractString)

Return the length of a UTF-8 message.
Note: utf-8 character has flexialbe length range from 1 to 4.
"""
utf8len(message::AbstractString) = length(codeunits(message))

"""
    bitarray2int(bits::AbstractVector)

Convert a bitarray to an integer.
"""
bitarray2int(bits::AbstractVector) = foldl((i, j) -> (i << 1 ⊻ j), bits)

"""
    bits2bytes(bits::AbstractVector)

Convert bits to bytes.

Note: The remainder bits will be truncated.
"""
function bits2bytes(bits::AbstractVector)
    nbits = length(bits)
    return @views UInt8[bitarray2int(bits[i:i + 7]) for i in 1:8:(nbits & 7 ⊻ nbits)]
end

## mode, indicator and message bits

"""
    getmode(message::AbstractString)

Return the encoding mode of `message`, either `Numeric()`, `Alphanumeric()`, 
`Byte()` or Kanji().

# Examples
```jldoctest
julia> getmode("HELLO WORLD")
Alphanumeric()
```

```jldoctest
julia> getmode("0123456")
Numeric()
```

```jldoctest
julia> getmode("12αβ")
UTF8()
```

```jldoctest
julia> getmode("茗荷")
Kanji()
```
"""
function getmode(message::AbstractString)
    ## message that contains only numbers
    all(isdigit, message) && return Numeric()

    ## message that contains only `alphanumeric` characters
    all(c -> haskey(alphanumeric, c), message) && return Alphanumeric()

    ## ISO-8859-1 characters -- the same as one-bit UTF-8 characters
    all(c -> 0 ≤ UInt32(c) ≤ 255, message) && return Byte()

    ## kanji characters
    all(c -> haskey(kanji, c), message) && return Kanji()

    ## utf-8 characters
    return UTF8()
end

"""
    getversion(message::AbstractString, mode::Mode, level::ErrCorrLevel)

Return the version of the QR code, between 1 and 40.

```jldoctest
julia> getversion("Hello World!", Alphanumeric(), High())
2
```
"""
function getversion(message::AbstractString, mode::Mode, eclevel::ErrCorrLevel)
    cc = characterscapacity[(eclevel, mode)]
    msglen = mode != UTF8() ? length(message) : utf8len(message)
    version = findfirst(≥(msglen), cc)
    isnothing(version) && throw(EncodeError("getversion: the input message is too long"))
    return version
end

"""
    getcharactercountindicator(msglength::Int,, version::Int, mode::Mode)

Return the bits for character count indicator.
"""
function getcharactercountindicator(msglength::Int,
                                    version::Int,
                                    mode::Mode)::BitArray{1}
    i = (version ≥ 1) + (version ≥ 10) + (version ≥ 27)
    cclength = charactercountlength[mode][i]
    indicator = int2bitarray(msglength; pad=cclength)
    return indicator
end

"""
    encodedata(message::AbstractString, ::Mode)

Encode the message with the given mode.
"""
function encodedata(message::AbstractString, ::Numeric)::BitArray{1}
    l = length(message)
    chunks = [SubString(message, i, min(i + 2, l)) for i in 1:3:l]

    function toBin(chunk::SubString)::BitArray
        pad = 1 + 3 * length(chunk)
        n = parse(Int, chunk)
        return  int2bitarray(n; pad=pad)
    end

    binchunks = map(toBin, chunks)
    return vcat(binchunks...)
end

function encodedata(message::AbstractString, ::Alphanumeric)::BitArray{1}
    l = length(message)
    chunks2 = [SubString(message, i, i + 1) for i in 1:2:l ⊻ (l & 1)]

    function toBin(s::SubString)::BitArray{1}
        n = 45 * alphanumeric[s[1]] + alphanumeric[s[2]]
        return  int2bitarray(n; pad=11)
    end

    binchunks2 = map(toBin, chunks2)
    if iseven(l)
        vcat(binchunks2...)
    else
        vcat(binchunks2..., int2bitarray(alphanumeric[last(message)]; pad=6))
    end
end

function encodedata(message::AbstractString, ::Byte)::BitArray{1}
    vcat(int2bitarray.(UInt8.(collect(message)))...)
end
function encodedata(message::AbstractString, ::UTF8)::BitArray{1}
    vcat(int2bitarray.(codeunits(message))...)
end

function encodedata(message::AbstractString, ::Kanji)::BitArray{1}
    vcat([int2bitarray(kanji[i]; pad=13) for i in message]...)
end

"""
    padencodedmessage(data::BitArray{1}, requiredlength::Int)

Pad the encoded message.
"""
function padencodedmessage(data::BitArray{1}, requiredlength::Int)
    length(data) > requiredlength && throw(EncodeError("padencodedmessage: the input data is too long"))
    
    # Add up to 4 zeros to terminate the message
    data = vcat(data, falses(min(4, requiredlength - length(data))))

    # Add zeros to make the length a multiple of 8
    if length(data) & 7 != 0
        data = vcat(data, falses(8 - length(data) & 7))
    end

    # Add the repeated pattern until reaching required length
    pattern = BitArray{1}([1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1])
    pad = repeat(pattern, ceil(Int, requiredlength - length(data) / 8))
    data = vcat(data, @view(pad[1:requiredlength - length(data)]))

    return data
end

## make blocks with error-correction bits

"""
    makeblocks(bits::BitArray{1}, nb1::Int, nc1::Int, nb2::Int, nc2::Int)

Divide the encoded message into 1 or 2 groups with `nbX` blocks in group `X` and
`ncX` codewords per block. Each block is a collection of integers which 
represents a message polynomial in GF(256).

The output is a collection of blocks, and each block is a collection of `UInt8` integers.
"""
function makeblocks(bits::BitArray{1}, nb1::Int, nc1::Int, nb2::Int, nc2::Int)
    bytes = bits2bytes(bits)
    
    ind = 1
    blocks = Vector{Vector{UInt8}}(undef, nb1 + nb2)
    for i in 1:nb1
        blocks[i] = @view(bytes[ind:ind + nc1 - 1])
        ind += nc1
    end
    for i in (nb1 + 1):(nb1 + nb2)
        blocks[i] = @view(bytes[ind:ind + nc2 - 1])
        ind += nc2
    end
    return blocks
end

"""
    getecblock(block::AbstractVector, ncodewords::Int)

Return the error correction blocks, with `ncodewords` codewords per block.
"""
function getecblock(block::AbstractVector, ncodewords::Int)
    ecpoly = geterrcode(Poly{UInt8}(@view(block[end:-1:1])), ncodewords)
    return @view(ecpoly.coeff[end:-1:1])
end

## interleave the blocks

"""
    interleave(blocks::AbstractVector, ecblocks::AbstractVector,
               ncodewords::Int, nb1::Int, nc1::Int, nb2::Int, nc2::Int,
               version::Int)

Mix the encoded data blocks and error correction blocks.
"""
function interleave( blocks::AbstractVector
                   , ecblocks::AbstractVector
                   , ncodewords::Int, nb1::Int
                   , nc1::Int, nb2::Int
                   , nc2::Int, version::Int
                   )::BitArray{1}
    bytes = Vector{UInt8}(undef, nb1 * (nc1 + ncodewords) + nb2 * (nc2 + ncodewords))
    ind = 1
    ## Encoded data
    for i in 1:nc1, j in 1:(nb1 + nb2)
        bytes[ind] = blocks[j][i]
        ind += 1
    end
    for i in nc1 + 1:nc2, j in (nb1 + 1):(nb1 + nb2)
        bytes[ind] = blocks[j][i]
        ind += 1
    end
    
    ## Error correction data
    for i in 1:ncodewords, j in 1:(nb1 + nb2)
        bytes[ind] = ecblocks[j][i]
        ind += 1
    end
    
    ## Extra padding
    bits = vcat(int2bitarray.(bytes; pad=8)...)
    msgbits = vcat(bits, falses(remainderbits[version]))

    return msgbits
end

"""
    encodemessage(msg::AbstractString, mode::Mode, eclevel::ErrCorrLevel, version::Int)

Encode message to bit array.
"""
function encodemessage(msg::AbstractString, mode::Mode, eclevel::ErrCorrLevel, version::Int)
    # Mode indicator: part of the encoded message
    modeindicator = modeindicators[mode]

    # Character count: part of the encoded message
    msglen = mode != UTF8() ? length(msg) : utf8len(msg) ## utf-8 has flexialbe length
    ccindicator = getcharactercountindicator(msglen, version, mode)

    # Encoded data: main part of the encoded message
    encodeddata = encodedata(msg, mode)

    # Getting parameters for the error correction
    # Number of error correction codewords per block, number of blocks in
    # group 1/2, number of data codewords per block in group 1/2
    ncodewords, nb1, nc1, nb2, nc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * nc1 + nb2 * nc2)

    # Pad encoded message before error correction
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)

    # Getting error correction codes
    blocks = makeblocks(encoded, nb1, nc1, nb2, nc2)
    ecblocks = getecblock.(blocks, ncodewords)

    # Interleave code blocks
    msgbits = interleave(blocks, ecblocks, ncodewords, nb1, nc1, nb2, nc2, version)

    return msgbits
end
