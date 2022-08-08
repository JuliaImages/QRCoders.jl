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
29×29 BitArray{2}:
 false  false  false  false  …  false  false  false
 false  false  false  false     false  false  false
     ⋮                       ⋱
 false  false  false  false     false  false  false
 false  false  false  false     false  false  false
```

The value `true` represents a dark space and `false` a white square.

There are two optional arguments: the error correction level (explained below) and `compact` which, when `true`, removes the white space around the code.

```julia
julia> qrcode("Hello world!", High(), compact = true)
25×25 BitArray{2}:
 true   true   true   true  …   true   true   true
 true  false  false  false     false  false   true
    ⋮                       ⋱
 true  false  false  false     false  false  false
 true   true   true   true     false  false   true
```

### Export a QR Code as a PNG file

Exporting files is also easy.

```julia
julia> exportqrcode("Hello world!")
```

A file will be saved at `./qrcode.png`.

> ![QRCode1](https://raw.githubusercontent.com/jiegillet/QRCode.jl/966b11d0334e050992d4167bda34a495fb334a6c/qrcode.png)

There are three optional parameters.

```julia
julia> exportqrcode("Hello world!", "img/hello.png", Medium(), targetsize = 10, compact = true)
```

This file will be saved as `./img/hello.png` (if the `img` directory already exists), have a size of (approximately) 10 centimeters and be compact. Please note that compact codes may be hard to read depending on their background.

> ![QRCode2](https://raw.githubusercontent.com/jiegillet/QRCode.jl/966b11d0334e050992d4167bda34a495fb334a6c/hello.png)

### Error Correction Level

QR Codes and be encoded with four error correction levels `Low`, `Medium`, `Quartile` and `High`. Error correction can restore missing data from the QR code.

* `Low` can restore up to 7% of missing codewords.
* `Medium` can restore up to 15% of missing codewords.
* `Quartile` can restore up to 25% of missing codewords.
* `High` can restore up to 30% of missing codewords.

The four levels are encoded as types in `QRCoders.jl`, grouped under the abstract type `ErrCorrLevel`. Don't forget to use parentheses when you call the values: `qrcode("Hello", High())`.

### Encoding Modes

QR Codes can encode data using several encoding schemes. `QRCoders.jl` supports three of them: `Numeric`, `Alphanumeric` and `Byte`.

`Numeric` is used for messages composed of digits only, `Alphanumeric` for messages composed of digits, characters `A`-`Z` (capital only) space and `%` `*` `+` `-` `.` `/` `:` `\$`, and `Bytes` for messages composed of ISO 8859-1 or UTF-8 characters. Please not that QR Code reader don't always support arbitrary UTF-8 characters.

### Acknowledgments

`QRCoders.jl` was built following this [excellent tutorial](https://www.thonky.com/qr-code-tutorial/).

`QRCoders.jl` was created during the [Efficient Scientific Computing with Julia](https://groups.oist.jp/grad/skill-pill-67) workshop, taught by [Valentin Churavy](https://github.com/vchuravy) at the [Okinawa Institute of Science and Technology](https://www.oist.jp) in July 2019. [Slides available here](https://github.com/JuliaLabs/Workshop-OIST).


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
