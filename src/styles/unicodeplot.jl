# 1. Unicode plot
## 1.1 by UnicodePlots.jl
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

## 1.2 Idea by @notinaboat
const pixelchars = ['█', '▀', '▄', ' ']
pixelchar(block::AbstractVector) = pixelchars[2 * block[1] + block[2] + 1]
pixelchar(bit::Bool) = bit ? pixelchars[4] : pixelchars[2]

"""
    unicodeplotbychar(mat::AbstractMatrix)

Plot of the QR code using Unicode characters.

The value `1(true)` represents a dark space and `0(false)` 
a white square. It is the same convention as QR code and 
is the opposite of general image settings.
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
"""
function unicodeplotbychar(message::AbstractString)
    unicodeplotbychar(qrcode(message; eclevel=Low(), width=2))
end