# QRCoders.jl Documentation

Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.

## Creating QR codes

```@docs
qrcode
exportqrcode
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
