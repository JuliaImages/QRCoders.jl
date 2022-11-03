# QRCoders.jl Documentation

Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.

## Creating QR codes

```@docs
qrcode
exportqrcode
QRCode
```

## styled QR codes

Plot in REPL.

```@docs
unicodeplot
unicodeplotbychar
```

## Encoding modes
There are five several encoding mode currently supported.

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

# Examples

Create a QR code matrix.

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

Export a QR code image from message.

```julia
julia> exportqrcode("Hello world!")
```

A file will be saved at `./qrcode.png`.

> ![QRCode1](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl@assets/qrcode.png)

Create a `.gif` file from messages.

```julia
julia> # QR codes with different masks
julia> using QRCoders: penalty
julia> codes = [QRCode("Hello world!", mask = i) for i in 0:7]
julia> qrcode.(codes) .|> penalty |> print
[425, 485, 342, 318, 495, 562, 368, 415]
julia> exportqrcode(codes, fps=3)
```

> ![QRCode-masks](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl/docs/src/assets/qrcode-masks.gif)