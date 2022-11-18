#=
# special QR codes
supported list:
    1. Unicode plot
        1.1 Unicode plot by UnicodePlots.jl
        1.2 Unicode plot by Unicode characters
    2. locate message bits
        2.1 extract indexes of message bits
        2.2 split indexes into several segments(de-interleave)
    3. plot image inside QR code
        3.1 use error correction
        3.2 use pad bits
        3.3 use pad bits and error correction
=#

# Unicode plot
include("unicodeplot.jl")

# locate message bits
include("locate.jl")

# Plot image inside QR code
include("plotimage.jl")
