# style of QR code
## support tables
## 1. unicode plot

# 1. unicode plot
"""
    unicodeplot(mat::AbstractMatrix{Bool}; border=:none)

Uses unicode characters to draw the matrix.
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

Uses unicode characters to draw the QR code of `message`.
"""
function unicodeplot(message::AbstractString; border=:none)
    unicodeplot(qrcode(message;eclevel=Low(), compact=false); border=border) 
end