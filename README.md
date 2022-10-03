# QRCoders

[![][action-img]][action-url]
[![][pkgeval-img]][pkgeval-url]
[![][codecov-img]][codecov-url]
[![][docs-stable-img]][docs-stable-url]
[![][docs-dev-img]][docs-dev-url]

Create [QR Codes](https://en.wikipedia.org/wiki/QR_code) as data within Julia, or export as PNG.

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

The value `1(true)` represents a dark space and `0(false)` a white square.

There are some optional arguments.

Keyword `compact` with default value `true`. 
If `compact` is `false`, the QR Code will be surrounded by a white border of width 3.

```julia
julia> qrcode("Hello world!", compact = false)
29×29 BitMatrix:
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
 ⋮              ⋮              ⋮              ⋮              ⋮              ⋮        
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
 0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
```

Keywords `eclevel`, `version`, `mode` and `mask`.
1. The error correction level `eclevel` can be picked from four values `Low()`, `Medium()`, `Quartile()` or `High()`. Higher levels make denser QR codes.

2. The version of the QR code `version` can be picked from 1 to 40. If the assigned version is too small to contain the message, the first available version is used.

3. The encoding mode `mode` can be picked from five values: `Numeric()`, `Alphanumeric()`, `Byte()`, `Kanji()` or `UTF8()`. If the assigned `mode` is `nothing` or is failed to contain the message, the mode will be picked automatically.

4. The mask pattern `mask` can be picked from 0 to 7. If the assigned `mask` is `nothing`, the mask pattern will picked by the penalty rules.

### Unicode Plot
Unicode plot of the QR Code.

```julia
julia> unicodeplot("Hello world!")
```
![深度截图_选择区域_20221003234211](https://cdn.jsdelivr.net/gh/zhihongecnu/PicBed3/picgo/深度截图_选择区域_20221003234211.png)

Note: this only works in the REPL.

### Export a QR Code as a PNG/JPG file

Exporting files is also easy.

```julia
julia> exportqrcode("Hello world!")
```

A file will be saved at `./qrcode.png`.

> ![QRCode1](https://raw.githubusercontent.com/jiegillet/QRCode.jl/966b11d0334e050992d4167bda34a495fb334a6c/qrcode.png)

There is an extra optional parameter for `exportqrcode`:

```julia
julia> exportqrcode("Hello world!", "img/hello.png", targetsize = 10, compact = true)
```

This file will be saved as `./img/hello.png` (if the `img` directory already exists), have a size of (approximately) 10 centimeters and be compact. Please note that compact codes may be hard to read depending on their background.

> ![QRCode2](https://raw.githubusercontent.com/jiegillet/QRCode.jl/966b11d0334e050992d4167bda34a495fb334a6c/hello.png)

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

### Acknowledgments

`QRCoders.jl` was built following this [excellent tutorial](https://www.thonky.com/qr-code-tutorial/).

The original repository [QRCode.jl](https://github.com/JuliaImages/QRCode.jl) was created during the [Efficient Scientific Computing with Julia](https://groups.oist.jp/grad/skill-pill-67) workshop, taught by [Valentin Churavy](https://github.com/vchuravy) at the [Okinawa Institute of Science and Technology](https://www.oist.jp) in July 2019. [Slides available here](https://github.com/JuliaLabs/Workshop-OIST).

The current version QRCoders.jl(v1.0.0) is proposed as part of the [OSPP'2022 project](https://summer-ospp.ac.cn/).

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
