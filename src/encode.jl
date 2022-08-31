# encode message into bit array
## outline
### 1. mode, indicator and message bits
### 2. make blocks with error-correction bits
### 3. interleave the blocks

using .Polynomial: Poly, geterrorcorrection

## mode, indicator and message bits

"""
    utf8len(message::AbstractString)

Return the length of a UTF-8 message.
Note that: utf-8 character has flexialbe length
"""
utf8len(message::AbstractString) = length(Vector{UInt8}(message))

"""
    getmode(message::AbstractString)

Return the encoding mode of `message`, either `Numeric()`, `Alphanumeric()`, 
`Byte()` or Kanji().

# Examples
```jldoctest
julia> getmode("HELLO WORLD")
Alphanumeric()
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
function getversion(message::AbstractString, mode::Mode, level::ErrCorrLevel)
    cc = characterscapacity[(level, mode)]
    version = findfirst(≥(length(message)), cc)
    isnothing(version) && throw(EncodeError("getversion: the input message is too long"))
    return version
end
function getversion(message::AbstractString, ::UTF8, level::ErrCorrLevel)
    cc = characterscapacity[(level, Byte())]
    version = findfirst(≥(utf8len(message)), cc)
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
    length(indicator) > cclength && throw(EncodeError("getcharactercountindicator: the input message is too long"))
    return indicator
end
getcharactercountindicator(msglength::Int, version::Int, ::UTF8) = getcharactercountindicator(msglength, version, Byte())

"""
    encodedata(message::AbstractString, ::Mode)

Encode the message with the given mode.
"""
function encodedata(message::AbstractString, ::Numeric)::BitArray{1}
    l = length(message)
    chunks = [SubString(message, i, min(i + 2, l)) for i in 1:3:l]

    function toBin(chunk::SubString)::BitArray
        num = parse(Int, chunk)
        num ≤ 9 && return int2bitarray(num; pad=4)
        num ≤ 99 && return int2bitarray(num; pad=7)
        return int2bitarray(num; pad=10)
    end
    return vcat(toBin.(chunks)...)
end

function encodedata(message::AbstractString, ::Alphanumeric)::BitArray{1}
    l = length(message)
    chunks = [SubString(message, i, min(i + 1, l)) for i in 1:2:l]

    function toBin(s::SubString)::BitArray{1}
        length(s) == 1 && return int2bitarray(alphanumeric[s[1]];pad=6);
        n = 45 * alphanumeric[s[1]] + alphanumeric[s[2]]
        return  int2bitarray(n; pad=11)
    end
    return vcat(toBin.(chunks)...)
end

function encodedata(message::AbstractString, ::Byte)::BitArray{1}
    vcat(int2bitarray.(UInt8.(collect(message)))...)
end
function encodedata(message::AbstractString, ::UTF8)::BitArray{1}
    vcat(int2bitarray.(Vector{UInt8}(message))...)
end

function encodedata(message::AbstractString, ::Kanji)::BitArray{1}
    vcat([int2bitarray(kanji[i]; pad=13) for i in message]...)
end

"""
    padencodedmessage(data::BitArray{1}, requiredlentgh::Int)

Pad the encoded message.
"""
function padencodedmessage(data::BitArray{1}, requiredlentgh::Int)
    length(data) > requiredlentgh && throw(EncodeError("padencodedmessage: the input data is too long"))
    
    # Add up to 4 zeros to terminate the message
    data = vcat(data, falses(min(4, requiredlentgh - length(data))))

    # Add zeros to make the length a multiple of 8
    if length(data) % 8 != 0
        data = vcat(data, falses(8 - length(data) % 8))
    end

    # Add the repeated pattern until reaching required length
    pattern = BitArray{1}([1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1])
    pad = repeat(pattern, ceil(Int, requiredlentgh - length(data) / 8))
    data = vcat(data, pad[1:requiredlentgh - length(data)])

    return data
end

## make blocks with error-correction bits

"""
    makeblocks(bits::BitArray{1}, nb1::Int, dc1::Int, nb2::Int, dc2::Int)

Divide the encoded message into 1 or 2 groups with `nbX` blocks in group `X` and
`dcX` codewords per block. Each block is a collection of integers(UInt8) which represents a message
polynomial in GF(256).
"""
function makeblocks(bits::BitArray{1},
                    nb1::Int,
                    dc1::Int,
                    nb2::Int,
                    dc2::Int)::Array{BitArray{2},1}
    array = reshape(bits, (8, length(bits) ÷ 8))
    i = 1
    blocks = BitArray{2}[]
    for n in 1:nb1
        push!(blocks, array[:, i:i + dc1 - 1])
        i += dc1
    end
    for n in 1:nb2
        push!(blocks, array[:, i:i + dc2 - 1])
        i += dc2
    end
    return blocks
end

"""
    geterrcorrblock(block::BitArray{2}, ncodewords::Int)

Return the error correction blocks, with `ncodewords` codewords per block.
"""
function geterrcorrblock(block::BitArray{2}, ncodewords::Int)::BitArray{2}
    # Helper functions
    bitarray2ints(b) = reduce((acc, n)->2 * acc + n, b, init = 0, dims = 1)
    array2poly(a) =  Poly(reverse(a[:]))

    poly = array2poly(bitarray2ints(block))
    ecpoly = geterrorcorrection(poly, ncodewords)
    ecarray = map(int2bitarray, reverse(ecpoly.coeff))
    ecbits = foldl(vcat, ecarray, init = BitArray{1}())
    return reshape(ecbits, (8, length(ecbits) ÷ 8))
end

## interleave the blocks

"""
    interleave(blocks::Array{BitArray{2},1}, ecblocks::Array{BitArray{2},1},
               ncodewords::Int, nb1::Int, dc1::Int, nb2::Int, dc2::Int,
               version::Int)

Mix the encoded data blocks and error correction blocks.
"""
function interleave( blocks::Array{BitArray{2},1}
                   , ecblocks::Array{BitArray{2},1}
                   , ncodewords::Int, nb1::Int
                   , dc1::Int
                   , nb2::Int
                   , dc2::Int
                   , version::Int
                   )::BitArray{1}

    data = BitArray{1}()

    slice(i) = (acc, block) -> vcat(acc, block[:, i])

    # Encoded data
    for i in 1:dc1
        data = foldl(slice(i), blocks, init = data)
    end
    if dc2 > dc1
        data = foldl(slice(dc2), blocks[nb1 + 1 : nb1 + nb2], init = data)
    end

    # Error correction data
    for i in 1:ncodewords
        data = foldl(slice(i), ecblocks, init = data)
    end

    # Extra padding
    data = vcat(data, falses(remainderbits[version]))

    return data
end

"""
    encodemessage(msg::AbstractString, mode::Mode, eclevel::ErrCorrLevel, version::Int)

Encode message to bit array.
"""
function encodemessage(msg::AbstractString, mode::Mode, eclevel::ErrCorrLevel, version::Int)
    # Mode indicator: part of the encoded message
    modeindicator = modeindicators[mode != UTF8() ? mode : Byte()]

    # Character count: part of the encoded message
    msglen = mode != UTF8() ? length(msg) : utf8len(msg) ## utf-8 has flexialbe length
    ccindicator = getcharactercountindicator(msglen, version, mode)

    # Encoded data: main part of the encoded message
    encodeddata = encodedata(msg, mode)

    # Getting parameters for the error correction
    # Number of error correction codewords per block, number of blocks in
    # group 1/2, number of data codewords per block in group 1/2
    ncodewords, nb1, dc1, nb2, dc2 = ecblockinfo[eclevel][version, :]
    requiredbits = 8 * (nb1 * dc1 + nb2 * dc2)

    # Pad encoded message before error correction
    encoded = vcat(modeindicator, ccindicator, encodeddata)
    encoded = padencodedmessage(encoded, requiredbits)

    # Getting error correction codes
    blocks = makeblocks(encoded, nb1, dc1, nb2, dc2)
    ecblocks = map(b->geterrcorrblock(b, ncodewords), blocks)

    # Interleave code blocks
    data = interleave(blocks, ecblocks, ncodewords, nb1, dc1, nb2, dc2, version)

    return data
end
