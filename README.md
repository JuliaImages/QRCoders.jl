# QRCoders

[![][action-img]][action-url]
[![][pkgeval-img]][pkgeval-url]
[![][codecov-img]][codecov-url]
[![][docs-stable-img]][docs-stable-url]
[![][docs-dev-img]][docs-dev-url]

Create [QR Codes](https://en.wikipedia.org/wiki/QR_code) as data within Julia, or export as PNG.

## Usage
### Create a QR Code as data

Creating a QR Code couldn't be simpler.

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

The value `1(true)` represents a dark space and `0(false)` a white space.

### Export a QR Code as a file

Exporting files is also easy.

```julia
julia> exportqrcode("Hello world!")
```

A file will be saved at `./qrcode.png`.

> ![QRCode1](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl@assets/qrcode.png)

### QRCode struct
`QRCode` is a structure type that contains the data of a QR Code.

```jl
julia> code = QRCode("Hello world!")
█████████████████████████
██ ▄▄▄▄▄ █▀ █ ▄█ ▄▄▄▄▄ ██
██ █   █ █▄ █▀▄█ █   █ ██
██ █▄▄▄█ █ ██▀ █ █▄▄▄█ ██
██▄▄▄▄▄▄▄█ ▀ ▀ █▄▄▄▄▄▄▄██
██▄ ▀ ▀▀▄ ▀ ▄███ ▄▄█▄ ▀██
████▄ █ ▄▄ █▄▀▄▄███ ▄▀ ██
██████▄█▄▄▀  ▀▄█▄▀ █▀█▀██
██ ▄▄▄▄▄ █▄  ▀▀ █ ▀▄▄▄███
██ █   █ █▀▄▀ ██▄ ▄▀▀▀ ██
██ █▄▄▄█ █▀  █▄▀▀█▄█▄█▄██
██▄▄▄▄▄▄▄█▄█▄▄▄██▄█▄█▄███
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
julia> exportqrcode(code)
```

Animated QR code is supported in version 1.3+.

```jl
julia> exportqrcode(["Hello world!", "Hello Julia!"], fps=2)
```

> ![QRCode2](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl@assets/hellojulia.gif)

The keyword `fps` controls the frame rate of the animation.

### Parameters

There are some optional arguments.

Keyword `width` with default value `0`. 

```julia
julia> qrcode("Hello world!", width=1)
23×23 BitMatrix:
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
 0  1  1  1  1  1  1  1  0  1  1  1  1  1  0  1  1  1  1  1  1  1  0
 0  1  0  0  0  0  0  1  0  1  0  1  0  1  0  1  0  0  0  0  0  1  0
 ⋮              ⋮              ⋮              ⋮              ⋮     
 0  1  0  0  0  0  0  1  0  0  1  0  1  0  1  1  1  1  0  0  0  1  0
 0  1  1  1  1  1  1  1  0  1  0  1  1  0  1  1  1  0  0  1  0  0  0
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
```

The QR Code will be surrounded by a white border of width `width`.

Keywords `eclevel`, `version`, `mode` and `mask` in `qrcode`:

1. Error correction level `eclevel` can be picked from four values `Low()`, `Medium()`, `Quartile()` or `High()`. Higher levels make denser QR codes.

2. Version of the QR code `version` can be picked from 1 to 40. If the assigned version is too small to contain the message, the first available version is used.

3. Encoding mode `mode` can be picked from five values: `Numeric()`, `Alphanumeric()`, `Byte()`, `Kanji()` or `UTF8()`. If the assigned `mode` is failed to contain the message, it will be picked automatically.

4. Mask pattern `mask` can be picked from 0 to 7. If the assigned `mask` is not valid, it will be picked automatically.

Keywords in `qrcode` are also available in `exportqrcode`. Moreover, a new keyword `pixels` is used to control the size of the exported image.

```julia
julia> exportqrcode("Hello world!", "img/hello.png", pixels = 160, width = 0)
```

This file will be saved as `./img/hello.png` (if the `img` directory already exists), have a size of (approximately) 160 centimeters and be compact.

> ![QRCode2](https://cdn.jsdelivr.net/gh/juliaimages/QRCoders.jl@assets/hello.png)

## About QRCode
### Error Correction Level

QR Codes can be encoded with four error correction levels `Low`, `Medium`, `Quartile` and `High`. Error correction can restore missing data from the QR code.

* `Low` can restore up to 7% of missing codewords.
* `Medium` can restore up to 15% of missing codewords.
* `Quartile` can restore up to 25% of missing codewords.
* `High` can restore up to 30% of missing codewords.

The four levels are encoded as types in `QRCoders.jl`, grouped under the abstract type `ErrCorrLevel`. Don't forget to use parentheses when you call the values: `qrcode("Hello", eclevel = High())`.

### Encoding Modes

QR Codes can encode data using several encoding schemes. `QRCoders.jl` supports five of them: `Numeric`, `Alphanumeric`, `Kanji`, `Byte` and `UTF8`.

`Numeric` is used for messages composed of digits only, `Alphanumeric` for messages composed of digits, characters `A`-`Z` (capital only) space and `%` `*` `+` `-` `.` `/` `:` `\$`, `Kanji` for kanji for Shift JIS(Shift Japanese Industrial Standards) characters, `Bytes` for messages composed of one-byte characters(including undefined characters), and `UTF8` for messages composed of Unicode characters.

Please note that QR Code reader don't always support arbitrary UTF-8 characters.

Another thing to point out is that, for `Byte` mode, we allow the use of undefined characters(Unicode range from 0x7f to 0x9f), following the original setting in QRCode.jl. For example:
```jl
julia> exportqrcode(join(Char.(0x80:0x9f)))
```
![qrcode](https://user-images.githubusercontent.com/62223937/190864667-0b24f7ad-e905-453d-a6fe-4d7d6d9feb15.png)

## Acknowledgments

`QRCoders.jl` was built following this [excellent tutorial](https://www.thonky.com/qr-code-tutorial/).

The original repository [QRCode.jl](https://github.com/JuliaImages/QRCode.jl) was created during the [Efficient Scientific Computing with Julia](https://groups.oist.jp/grad/skill-pill-67) workshop, taught by [Valentin Churavy](https://github.com/vchuravy) at the [Okinawa Institute of Science and Technology](https://www.oist.jp) in July 2019. [Slides available here](https://github.com/JuliaLabs/Workshop-OIST).

The current version QRCoders.jl(≥v1.0.0) is proposed as part of the [OSPP'2022 project](https://summer-ospp.ac.cn/).

<!-- URLS -->

[pkgeval-img]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/Q/QRCode.svg
[pkgeval-url]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/report.html
[action-img]: https://github.com/JuliaImages/QRCoders.jl/workflows/CI/badge.svg
[action-url]: https://github.com/JuliaImages/QRCoders.jl/actions
[codecov-img]: https://codecov.io/github/JuliaImages/QRCoders.jl/coverage.svg?branch=master
[codecov-url]: https://codecov.io/github/JuliaImages/QRCoders.jl?branch=master
[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://JuliaImages.github.io/QRCoders.jl/stable
[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://JuliaImages.github.io/QRCoders.jl/latest
