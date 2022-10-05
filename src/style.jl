# style of QR code
## support tables
## 1. Unicode plot

# 1. Unicode plot
"""
    unicodeplot(mat::AbstractMatrix{Bool}; border=:none)

Uses UnicodePlots.jl to draw the matrix.
"""
function unicodeplot(mat::AbstractMatrix{Bool}; border=:none)
    width, height = size(mat)
    return heatmap(mat;
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
    unicodeplot(qrcode(message;eclevel=Low(), compact=false, width=2); border=border) 
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
    unicodeplotbychar(.! qrcode(message; eclevel=Low(), compact=false, width=2))
end