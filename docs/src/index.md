# QRCode.jl Documentation

Module that can create QR codes as data or images using `qrcode` or `exportqrcode`.

## Creating QR codes

```@docs
qrcode
exportqrcode
getversion
getmode
```

## Encoding modes
There are three several encoding mode currently supported.

```@docs
Mode
Numeric
Alphanumeric
Byte
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
