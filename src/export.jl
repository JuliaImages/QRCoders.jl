# Generate and export QR codes

"""supported extensions"""
const supportexts = ["png", "jpg", "jpeg", "gif"]

"""
    qrcode( message::AbstractString
          ; eclevel::ErrCorrLevel = Medium()
          , version::Int = 0
          , mode::Mode = Numeric()
          , mask::Int = -1
          , width::Int=0)

Create a `BitArray{2}` with the encoded `message`, with `true` (`1`) for the black
areas and `false` (`0`) as the white ones.

The error correction level `eclevel` can be picked from four values: `Low()`
(7% of missing data can be restored), `Medium()` (15%), `Quartile()` (25%) or
`High()` (30%). Higher levels make denser QR codes.

The version of the QR code can be picked from 1 to 40. If the assigned version is 
too small to contain the message, the first available version is used.

The encoding mode `mode` can be picked from five values: `Numeric()`, `Alphanumeric()`,
`Byte()`, `Kanji()` or `UTF8()`. If the assigned `mode` is `nothing` or failed to contain the message,
the mode is automatically picked.

The mask pattern `mask` can be picked from 0 to 7. If the assigned `mask` is `nothing`,
the mask pattern will picked by the penalty rules.
"""
function qrcode(message::AbstractString
    ; eclevel::ErrCorrLevel=Medium(), version::Int=0, mode::Mode=Numeric(), mask::Int=-1, compact::Bool=false, width::Int=0)
    isempty(message) && @warn(
        "Most QR code scanners don't support empty message!")
    # Determining mode and version of the QR code
    bestmode = getmode(message)
    mode = bestmode ⊆ mode ? mode : bestmode

    version > 40 && throw(EncodeError("Version $version should be no larger than 40"))
    minversion = getversion(message, mode, eclevel)
    if version < minversion # the specified version is too small
        version = minversion
    end

    # encode message
    data = encodemessage(message, mode, eclevel, version)

    # Generate qr code matrix
    matrix = emptymatrix(version)
    masks = makemasks(matrix) # 8 masks
    matrix = placedata!(matrix, data) # fill in data bits
    addversion!(matrix, version) # fill in version bits

    # Apply mask and add format information
    maskedmats = [addformat!(xor.(matrix, mat), i - 1, eclevel)
                  for (i, mat) in enumerate(masks)]

    # Pick the best mask
    if !(0 ≤ mask ≤ 7) # invalid mask
        mask = argmin(penalty.(maskedmats)) - 1
    end
    matrix = maskedmats[mask+1]

    # white border
    (compact || width == 0) && return matrix # keyword compact will be removed in the future
    return addborder(matrix, width)
end

"""
    _resize(matrix::AbstractMatrix, widthpixels::Int)

Resize the width of the QR code to `widthpixels` pixels(approximately).

Note: the size of the resulting matrix is an integer multiple of the size of the original one.
"""
function _resize(matrix::AbstractMatrix, widthpixels::Int=160)
    scale = ceil(Int, widthpixels / size(matrix, 1))
    kron(matrix, trues(scale, scale))
end

"""
Check whether the path is valid.
"""
function _checkpath(path::AbstractString, supportexts::AbstractVector{<:AbstractString})
    if !endswith(path, r"\.\w+")
        path *= ".png"
    else
        ext = last(split(path, '.'))
        ext ∈ supportexts || throw(EncodeError(
            "Unsupported file extension: $ext\n Supported extensions: $supportexts"))
    end
    return path
end

"""
    exportbitmat(matrix::BitMatrix, path::AbstractString; pixels::Int = 160)
    
Export the `BitMatrix` `matrix` to an image with file path `path`.
"""
function exportbitmat(matrix::AbstractMatrix{Bool}, path::AbstractString
    ; targetsize::Int=0, pixels::Int=160)
    # check whether the image format is supported
    # supportexts = ["png", "jpg", "jpeg", "gif"] read from the predifined const
    path = _checkpath(path, supportexts)

    # resize the matrix
    if targetsize > 0 # original keyword -- will be removed in the future
        Base.depwarn("keyword `targetsize` will be removed in the future, use `pixels` instead", :exportbitmat)
        n = size(matrix, 1)
        pixels = ceil(Int, 72 * targetsize / 2.45 / n) * n
    end
    save(path, .!_resize(matrix, pixels))
end
exportbitmat(path::AbstractString) = matrix -> exportbitmat(matrix, path)

"""
    exportqrcode( message::AbstractString
                , path::AbstractString = "qrcode.png"
                ; eclevel::ErrCorrLevel = Medium()
                , version::Int = 0
                , mode::Mode = nothing
                , width::int = 4
                , pixels::Int = 160)

Create an image with the encoded `message` of approximate size `pixels x pixels`.

The error correction level `eclevel` can be picked from four values: `Low()`
(7% of missing data can be restored), `Medium()` (15%), `Quartile()` (25%) or
`High()` (30%). Higher levels make denser QR codes.

The version of the QR code can be picked from 1 to 40. If the assigned version is 
too small to contain the message, the first available version is used.

The encoding mode `mode` can be picked from four values: `Numeric()`, `Alphanumeric()`,
`Byte()`, `Kanji()` or `UTF8()`. If the assigned `mode` is `nothing` or failed to contain the message,
the mode is automatically picked.

The mask pattern `mask` can be picked from 0 to 7. If the assigned `mask` is `nothing`,
the mask pattern will picked by the penalty rules.
"""
function exportqrcode(message::AbstractString, path::AbstractString="qrcode.png"
    ; eclevel::ErrCorrLevel=Medium(), version::Int=0, mode::Mode=Numeric(), mask::Int=-1, width::Int=4, compact::Bool=false, targetsize::Int=0, pixels::Int=160)
    # encode data
    matrix = qrcode(message; eclevel=eclevel,
        version=version,
        mode=mode,
        mask=mask,
        compact=compact,
        width=width)
    exportbitmat(matrix, path; targetsize=targetsize, pixels=pixels)
end

# new API for qrcode and exportqrcode
"""
    qrcode(code::QRCode)

Create a QR code matrix by the `QRCode` object.

Note: It would raise an error if failed to use the specified `mode`` or `version`.
"""
function qrcode(code::QRCode)
    # raise error if failed to use the specified mode or version
    mode, eclevel, version, mask = code.mode, code.eclevel, code.version, code.mask
    message, width = code.message, code.border
    getmode(message) ⊆ mode || throw(EncodeError("Mode $mode can not encode the message"))
    getversion(message, mode, eclevel) ≤ version ≤ 40 || throw(EncodeError("The version $version is too small"))

    # encode message
    data = encodemessage(message, mode, eclevel, version)

    # Generate qr code matrix
    matrix = emptymatrix(version)
    maskmat = makemask(matrix, mask)
    matrix = placedata!(matrix, data) # fill in data bits
    addversion!(matrix, version) # fill in version bits
    matrix = addformat!(xor.(matrix, maskmat), mask, eclevel)

    # white border
    addborder(matrix, width)
end

"""
    exportqrcode( code::QRCode
                , path::AbstractString = "qrcode.png"
                ; pixels::Int = 160)

Create an image with the encoded `message` of approximate size `targetsize`.
"""
function exportqrcode(code::QRCode, path::AbstractString="qrcode.png"
    ; targetsize::Int=0, pixels::Int=160)
    matrix = qrcode(code)
    exportbitmat(matrix, path; targetsize=targetsize, pixels=pixels)
end

"""
    exportqrcode( codes::AbstractVector{QRCode}
                , path::AbstractString = "qrcode.gif"
                ; pixels::Int = 160
                , fps::Int = 2)

Create an animated gif with `codes` of approximate size `targetsize`.

The frame rate `fps` is the number of frames per second.

Note: The `codes` should have the same size while the other properties can be different.
"""
function exportqrcode(codes::AbstractVector{QRCode}, path::AbstractString="qrcode.gif"
    ; targetsize::Int=0, pixels::Int=160, fps::Int=2)
    matwidth = qrwidth(first(codes))
    all(==(matwidth), qrwidth.(codes)) || throw(EncodeError("The codes should have the same size"))
    # check whether the image format is supported
    path = _checkpath(path, ["gif"])

    # generate frames
    if targetsize > 0 # original keyword -- will be removed in the future
        Base.depwarn("keyword `targetsize` will be removed in the future, use `pixels` instead", :exportbitmat)
        pixels = ceil(Int, 72 * targetsize / 2.45 / matwidth) * matwidth
    else
        pixels = ceil(Int, pixels / matwidth) * matwidth
    end
    save(path, .!cat([_resize(qrcode(code), pixels) for code in codes]..., dims=3), fps=fps)
end

"""
    exportqrcode( msgs::AbstractVector{<:AbstractString}
                , path::AbstractString = "qrcode.gif"
                ; eclevel::ErrCorrLevel = Medium()
                , version::Int = 0
                , mode::Mode = Numeric()
                , mask::Int = -1
                , width::Int = 4
                , targetsize::Int = 5
                , pixels::Int = 160
                , fps::Int = 2)

Create an animated gif with `msgs` of approximate size `pixels x pixels`.

The frame rate `fps` is the number of frames per second.
"""
function exportqrcode(msgs::AbstractVector{<:AbstractString}, path::AbstractString="qrcode.gif"
    ; eclevel::ErrCorrLevel=Medium(), version::Int=0, mode::Mode=Numeric(), mask::Int=-1, width::Int=4, targetsize::Int=0, pixels::Int=160, fps::Int=2)
    codes = QRCode.(msgs
        ; eclevel=eclevel, version=version, mode=mode, mask=mask, width=width)
    # the image should have the same size
    ## method 1: edit version
    version = maximum(getproperty.(codes, :version))
    setproperty!.(codes, :version, version)
    ## method 2: enlarge width of the small ones
    # maxwidth = first(maximum(qrwidth.(codes)))
    # for code in codes
    #     code.border += (maxwidth - qrwidth(code)) ÷ 2
    # end
    # setproperty!.(codes, :width, width)
    exportqrcode(codes, path; targetsize=targetsize, pixels=pixels, fps=fps)
end

"""
    exportsvg(msg::AbstractString; size=240, border=4, path=nothing,
              darkcolor="#000", lightcolor="#fff")

Export a QR code as an SVG string. 
If `path` is set, also write the SVG there.

# Color:
- `darkcolor`: color for “black” (usually modules), CSS string.
- `lightcolor`: background color, CSS string.

# Examples
```jldoctest
julia> using QRCoders

julia> s = exportsvg("Hello!");  # SVG string (default black on white)

julia> s = exportsvg("Color Demo"; darkcolor="navy", lightcolor="#ffb"); 

julia> tmp = mktempdir();

julia> file_path = joinpath(tmp, "hello.svg")

julia> exportsvg("Another code"; path=file_path);   # Writes file
```
"""
function exportsvg(
    msg::AbstractString; size=240, border=4, path::Union{Nothing,String}=nothing,
    darkcolor="#000", lightcolor="#fff")
    mat = qrcode(msg; width=border)
    n   = Base.size(mat, 1)
    sc  = size ÷ n
    io  = IOBuffer()
    println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$(n*sc)\" "*
             "height=\"$(n*sc)\" viewBox=\"0 0 $n $n\">")
    println(io, "<rect width=\"$n\" height=\"$n\" fill=\"$lightcolor\"/>")
    for y in 1:n, x in 1:n
        mat[y,x] && println(io, "<rect x=\"$(x-1)\" y=\"$(y-1)\" width=\"1\" "* 
            "height=\"1\" fill=\"$darkcolor\"/>")
    end
    println(io, "</svg>")
    svg = String(take!(io))
    if !isnothing(path)
        open(path, "w") do f; write(f, svg); end
    end
    return svg
end

"""
    matrix2svg(mat::AbstractMatrix{Bool};
               size::Integer=240,
               darkcolor::AbstractString="#000",
               lightcolor::AbstractString="#fff",
               path::Union{Nothing,AbstractString}=nothing)

Render a Boolean matrix (as produced by QRCoders' `qrcode` or `imageinqrcode`) as
an SVG string. If `path` is provided, the SVG is also saved to that file.

- `mat`: 2D Boolean array, where `true` means a dark (“on”) QR module and `false`
  means a light module.
- `size`: Total image size in pixels (width and height). Default 240.
- `darkcolor`: CSS color string for dark (data) modules. Default `"#000"`.
- `lightcolor`: CSS color string for background. Default `"#fff"`.
- `path`: Optional file name. If set, SVG will additionally be written to file.


A string containing the SVG XML markup for the QR code.

# Examples

```julia
julia> using QRCoders, TestImages, ColorTypes, ImageTransformations

julia> oriimg = testimage("cameraman");

julia> code = QRCode("Hello world!", version=16, width=4);

julia> img = imresize(oriimg, 66, 66) .|> Gray .|> round .|> Bool .|> !;

julia> qrmat = imageinqrcode(code, img; rate=0.9);

julia> svgstr = matrix2svg(qrmat; darkcolor="black", lightcolor="white");

julia> tmp = mktempdir();

julia> outpath = joinpath(tmp, "qrwithimage.svg")
[...]

julia> open(outpath, "w") do f; write(f, svgstr); end;

julia> println(string("Wrote SVG to: ",outpath))
[...]

```
"""
function matrix2svg(mat::AbstractMatrix{Bool};
    size::Integer=240,
    darkcolor::AbstractString="#000",
    lightcolor::AbstractString="#fff",
    path::Union{Nothing,AbstractString}=nothing)
    n = Base.size(mat, 1)
    sc = size ÷ n
    io = IOBuffer()
    println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$(n*sc)\" " *
                "height=\"$(n*sc)\" viewBox=\"0 0 $n $n\">")
    println(io, "<rect width=\"$n\" height=\"$n\" fill=\"$lightcolor\"/>")
    for y in 1:n, x in 1:n
        mat[y, x] && println(io,
            "<rect x=\"$(x-1)\" y=\"$(y-1)\" width=\"1\" height=\"1\" " *
            "fill=\"$darkcolor\"/>")
    end
    println(io, "</svg>")
    svg = String(take!(io))
    if !isnothing(path)
        open(path, "w") do f
            write(f, svg)
        end
    end
    return svg
end