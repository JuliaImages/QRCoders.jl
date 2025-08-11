# QRCoders.jl Documentation

Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.

## Creating QR codes

```@docs
qrcode
exportqrcode
exportsvg
QRCode
```

## Encoding modes
Currently, there are five supported encoding modes.

```@docs
Mode
Numeric
Alphanumeric
Byte
Kanji
UTF8
```

## Error Correction
There are four error correction levels you can choose from.

```@docs
ErrCorrLevel
Low
Medium
Quartile
High
```

## Reed Solomon code

```@docs
Poly
generator_matrix
geterrcode
```
## styled QR codes

Plot in REPL.

```@docs
unicodeplot
unicodeplotbychar
```

Plot image in a QR code.

```@docs
imageinqrcode
matrix2svg
```

# Examples

## Create a QR code matrix

```julia
julia> using QRCoders

julia> qrcode("Hello world!")
21×21 BitMatrix:
 1  1  1  1  1  1  1  0  1  1  1  1  1  0  1  1  1  1  1  1  1
 1  0  0  0  0  0  1  0  1  0  1  0  1  0  1  0  0  0  0  0  1
 1  0  1  1  1  0  1  0  0  0  1  1  0  0  1  0  1  1  1  0  1
 ⋮              ⋮              ⋮              ⋮              ⋮
 1  0  1  1  1  0  1  0  1  0  0  0  1  0  0  1  0  0  1  0  0
 1  0  0  0  0  0  1  0  0  1  0  1  0  1  1  1  1  0  0  0  1
 1  1  1  1  1  1  1  0  1  0  1  1  0  1  1  1  0  0  1  0  0
```

## Export to a file
### PNG file -- default
```julia
julia> exportqrcode("Hello world!")
```

A file will be saved at `./qrcode.png`.

> ![QRCode1](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl@assets/qrcode.png)

### GIF file
Create a `.gif` file from messages.

Use `.gif` file to show QR codes with different masks.
```julia
julia> using QRCoders: penalty
julia> codes = [QRCode("Hello world!", mask = i) for i in 0:7]
julia> qrcode.(codes) .|> penalty |> print
[425, 485, 342, 318, 495, 562, 368, 415]
julia> exportqrcode(codes, fps=3)
```

> ![QRCode-masks](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl/docs/src/assets/qrcode-masks.gif)


### Export or Display as SVG

You can generate a QR code as an SVG string, control its size and colors, and write it to a file.

#### Simple usage

```julia
julia> using QRCoders

julia> svgstr = exportsvg("Hello!");  # Black on white SVG string

julia> tmp = mktempdir();

julia> file_path = joinpath(tmp, "hello.svg")

julia> exportsvg("Another code"; path=file_path)   # Writes SVG file
```

#### Custom colors

You can set module/background CSS colors:

```julia
julia> s = exportsvg("Color Demo"; darkcolor="navy", lightcolor="#ffb");
```

You can then display the SVG in a browser, include it in an HTML page, or use it directly in web applications.

### Styles of QRCode
> This part is still under development, see [issue#33](https://github.com/JuliaImages/QRCoders.jl/issues/33) for more information. Feel free to contribute or propose more ideas!

Plot an image inside a QRCode.

```julia
julia> using TestImages, ColorTypes, ImageTransformations

julia> using QRCoders

julia> oriimg = testimage("cameraman")

julia> code = QRCode("Hello world!", version=16, width=4)

julia> img = imresize(oriimg, 66, 66) .|> Gray .|> round .|> Bool .|> !

julia> imageinqrcode(code, img; rate=0.9) |> exportbitmat("qrcode-camera.png")
```

For SGV do this:


#### Advanced: Render any Boolean matrix as SVG

To display a QR code or styled/custom QR overlays (e.g. using images), use `matrix2svg`:

```julia
julia> using TestImages, ColorTypes, ImageTransformations

julia> oriimg = testimage("cameraman")

julia> code = QRCode("Hello world!", version=16, width=4)

julia> img = imresize(oriimg, 66, 66) .|> Gray .|> round .|> Bool .|> !

julia> qrmat = imageinqrcode(code, img; rate=0.9)

julia> svgout = matrix2svg(qrmat; darkcolor="maroon", lightcolor="#faf9f1")

julia> open("myfancyqr.svg", "w") do f; write(f, svgout); end
```

> ![cameraman](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl@assets/qrcode-camera.png)

Here `rate` is the damage rate of error correction codewords, it should be no greater than 1.
