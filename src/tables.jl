# Data tables from the specificatioms

"""
Allowed characters for `Alphanumeric()` mode and their number.
"""
const alphanumeric = Dict{AbstractChar, Int}(
  zip(vcat('0':'9', 'A':'Z', collect(" \$%*+-./:")), 0:44))

const antialphanumeric = Dict{Int, AbstractChar}(val => key for (key, val) in alphanumeric)

include("kanji.jl")
const antikanji = Dict{Int, AbstractChar}(val => key for (key, val) in kanji)

"""
Number of characters allowed for a given mode, error correction level and
version.
"""
const characterscapacity = Dict{Tuple{ErrCorrLevel, Mode}, Array{Int, 1}}(
    (Low(), Numeric()) =>
        [41, 77, 127, 187, 255, 322, 370, 461, 552, 652, 772, 883, 1022, 1101,
         1250, 1408, 1548, 1725, 1903, 2061, 2232, 2409, 2620, 2812, 3057, 3283,
         3517, 3669, 3909, 4158, 4417, 4686, 4965, 5253, 5529, 5836, 6153, 6479,
         6743, 7089]
  , (Low(), Alphanumeric()) =>
        [25, 47, 77, 114, 154, 195, 224, 279, 335, 395, 468, 535, 619, 667, 758,
         854, 938, 1046, 1153, 1249, 1352, 1460, 1588, 1704, 1853, 1990, 2132,
         2223, 2369, 2520, 2677, 2840, 3009, 3183, 3351, 3537, 3729, 3927, 4087,
         4296]
  , (Low(), Byte()) =>
        [17, 32, 53, 78, 106, 134, 154, 192, 230, 271, 321, 367, 425, 458, 520,
         586, 644, 718, 792, 858, 929, 1003, 1091, 1171, 1273, 1367, 1465, 1528,
         1628, 1732, 1840, 1952, 2068, 2188, 2303, 2431, 2563, 2699, 2809, 2953]
  , (Low(), UTF8()) =>
         [17, 32, 53, 78, 106, 134, 154, 192, 230, 271, 321, 367, 425, 458, 520,
          586, 644, 718, 792, 858, 929, 1003, 1091, 1171, 1273, 1367, 1465, 1528,
          1628, 1732, 1840, 1952, 2068, 2188, 2303, 2431, 2563, 2699, 2809, 2953]
  , (Low(), Kanji()) => [10, 20, 32, 48, 65, 82, 95, 118, 141, 167, 198, 226, 
         262, 282, 320, 361, 397, 442, 488, 528, 572, 618, 672, 721, 784, 842, 
         902, 940, 1002, 1066, 1132, 1201, 1273, 1347, 1417, 1496, 1577, 1661,
         1729, 1817]
  , (Medium(), Numeric()) =>
        [34, 63, 101, 149, 202, 255, 293, 365, 432, 513, 604, 691, 796, 871,
         991, 1082, 1212, 1346, 1500, 1600, 1708, 1872, 2059, 2188, 2395, 2544,
         2701, 2857, 3035, 3289, 3486, 3693, 3909, 4134, 4343, 4588, 4775, 5039,
         5313, 5596]
  , (Medium(), Alphanumeric()) =>
        [20, 38, 61, 90, 122, 154, 178, 221, 262, 311, 366, 419, 483, 528, 600,
         656, 734, 816, 909, 970, 1035, 1134, 1248, 1326, 1451, 1542, 1637,
         1732, 1839, 1994, 2113, 2238, 2369, 2506, 2632, 2780, 2894, 3054, 3220,
         3391]
  , (Medium(), Byte()) =>
        [14, 26, 42, 62, 84, 106, 122, 152, 180, 213, 251, 287, 331, 362, 412,
         450, 504, 560, 624, 666, 711, 779, 857, 911, 997, 1059, 1125, 1190,
         1264, 1370, 1452, 1538, 1628, 1722, 1809, 1911, 1989, 2099, 2213, 2331]
  , (Medium(), UTF8()) =>
        [14, 26, 42, 62, 84, 106, 122, 152, 180, 213, 251, 287, 331, 362, 412,
         450, 504, 560, 624, 666, 711, 779, 857, 911, 997, 1059, 1125, 1190,
         1264, 1370, 1452, 1538, 1628, 1722, 1809, 1911, 1989, 2099, 2213, 2331]
  , (Medium(), Kanji()) =>
        [8, 16, 26, 38, 52, 65, 75, 93, 111, 131, 155, 177, 204, 223, 254, 277,
         310, 345, 384, 410, 438, 480, 528, 561, 614, 652, 692, 732, 778, 843, 
         894, 947, 1002, 1060, 1113, 1176, 1224, 1292, 1362, 1435]
  , (Quartile(), Numeric()) =>
        [27, 48, 77, 111, 144, 178, 207, 259, 312, 364, 427, 489, 580, 621, 703,
         775, 876, 948, 1063, 1159, 1224, 1358, 1468, 1588, 1718, 1804, 1933,
         2085, 2181, 2358, 2473, 2670, 2805, 2949, 3081, 3244, 3417, 3599, 3791,
         3993]
  , (Quartile(), Alphanumeric()) =>
        [16, 29, 47, 67, 87, 108, 125, 157, 189, 221, 259, 296, 352, 376, 426,
         470, 531, 574, 644, 702, 742, 823, 890, 963, 1041, 1094, 1172, 1263,
         1322, 1429, 1499, 1618, 1700, 1787, 1867, 1966, 2071, 2181, 2298, 2420]
  , (Quartile(), Byte()) =>
        [11, 20, 32, 46, 60, 74, 86, 108, 130, 151, 177, 203, 241, 258, 292,
         322, 364, 394, 442, 482, 509, 565, 611, 661, 715, 751, 805, 868, 908,
         982, 1030, 1112, 1168, 1228, 1283, 1351, 1423, 1499, 1579, 1663]
  , (Quartile(), UTF8()) =>
         [11, 20, 32, 46, 60, 74, 86, 108, 130, 151, 177, 203, 241, 258, 292,
          322, 364, 394, 442, 482, 509, 565, 611, 661, 715, 751, 805, 868, 908,
          982, 1030, 1112, 1168, 1228, 1283, 1351, 1423, 1499, 1579, 1663]
  , (Quartile(), Kanji()) =>
        [7, 12, 20, 28, 37, 45, 53, 66, 80, 93, 109, 125, 149, 159, 180, 198, 
         224, 243, 272, 297, 314, 348, 376, 407, 440, 462, 496, 534, 559, 604,
          634, 684, 719, 756, 790, 832, 876, 923, 972, 1024]
  , (High(), Numeric()) =>
        [17, 34, 58, 82, 106, 139, 154, 202, 235, 288, 331, 374, 427, 468, 530,
         602, 674, 746, 813, 919, 969, 1056, 1108, 1228, 1286, 1425, 1501, 1581,
         1677, 1782, 1897, 2022, 2157, 2301, 2361, 2524, 2625, 2735, 2927, 3057]
  , (High(), Alphanumeric()) =>
        [10, 20, 35, 50, 64, 84, 93, 122, 143, 174, 200, 227, 259, 283, 321,
         365, 408, 452, 493, 557, 587, 640, 672, 744, 779, 864, 910, 958, 1016,
         1080, 1150, 1226, 1307, 1394, 1431, 1530, 1591, 1658, 1774, 1852]
  , (High(), Byte()) =>
        [7, 14, 24, 34, 44, 58, 64, 84, 98, 119, 137, 155, 177, 194, 220, 250,
         280, 310, 338, 382, 403, 439, 461, 511, 535, 593, 625, 658, 698, 742,
         790, 842, 898, 958, 983, 1051, 1093, 1139, 1219, 1273]
  , (High(), UTF8()) =>
         [7, 14, 24, 34, 44, 58, 64, 84, 98, 119, 137, 155, 177, 194, 220, 250,
          280, 310, 338, 382, 403, 439, 461, 511, 535, 593, 625, 658, 698, 742,
          790, 842, 898, 958, 983, 1051, 1093, 1139, 1219, 1273]
  , (High(), Kanji()) => 
  [4, 8, 15, 21, 27, 36, 39, 52, 60, 74, 85, 96, 109, 120, 136, 154, 173, 191,
   208, 235, 248, 270, 284, 315, 330, 365, 385, 405, 430, 457, 486, 518, 553, 
   590, 605, 647, 673, 701, 750, 784]
  )

"""
Mode indicators.
"""
const modeindicators = Dict{Mode, BitArray{1}}(
    Numeric()      => BitArray([0, 0, 0, 1])
  , Alphanumeric() => BitArray([0, 0, 1, 0])
  , Byte()         => BitArray([0, 1, 0, 0])
  , UTF8()         => BitArray([0, 1, 0, 0]) # same indicator as Byte
  , Kanji()        => BitArray([1, 0, 0, 0])
  )

"""
Character count length for different mode and version groups.
"""
const charactercountlength = Dict{Mode, Array{Int, 1}}(
    Numeric()      => [10, 12, 14]
  , Alphanumeric() => [9, 11, 13]
  , Byte()         => [8, 16, 16]
  , UTF8()         => [8, 16, 16] # same as Byte
  , Kanji()        => [8, 10, 12]
  )

"""
Information about the error correction codeblocks per level and version
(eclevel, numofblock1s, block1length, numofblock2s, block2length).
"""
const ecblockinfo = Dict{ErrCorrLevel,Array{Int,2}}(
    Low() =>
      [7 1 19 0 0; 10 1 34 0 0; 15 1 55 0 0; 20 1 80 0 0; 26 1 108 0 0;
       18 2 68 0 0; 20 2 78 0 0; 24 2 97 0 0; 30 2 116 0 0; 18 2 68 2 69;
       20 4 81 0 0; 24 2 92 2 93; 26 4 107 0 0; 30 3 115 1 116; 22 5 87 1 88;
       24 5 98 1 99; 28 1 107 5 108; 30 5 120 1 121; 28 3 113 4 114;
       28 3 107 5 108; 28 4 116 4 117; 28 2 111 7 112; 30 4 121 5 122;
       30 6 117 4 118; 26 8 106 4 107; 28 10 114 2 115; 30 8 122 4 123;
       30 3 117 10 118; 30 7 116 7 117; 30 5 115 10 116; 30 13 115 3 116;
       30 17 115 0 0; 30 17 115 1 116; 30 13 115 6 116; 30 12 121 7 122;
       30 6 121 14 122; 30 17 122 4 123; 30 4 122 18 123; 30 20 117 4 118;
       30 19 118 6 119]
  , Medium() =>
    [10 1 16 0 0; 16 1 28 0 0; 26 1 44 0 0; 18 2 32 0 0; 24 2 43 0 0;
     16 4 27 0 0; 18 4 31 0 0; 22 2 38 2 39; 22 3 36 2 37; 26 4 43 1 44;
     30 1 50 4 51; 22 6 36 2 37; 22 8 37 1 38; 24 4 40 5 41; 24 5 41 5 42;
     28 7 45 3 46; 28 10 46 1 47; 26 9 43 4 44; 26 3 44 11 45; 26 3 41 13 42;
     26 17 42 0 0; 28 17 46 0 0; 28 4 47 14 48; 28 6 45 14 46; 28 8 47 13 48;
     28 19 46 4 47; 28 22 45 3 46; 28 3 45 23 46; 28 21 45 7 46; 28 19 47 10 48;
     28 2 46 29 47; 28 10 46 23 47; 28 14 46 21 47; 28 14 46 23 47;
     28 12 47 26 48; 28 6 47 34 48; 28 29 46 14 47; 28 13 46 32 47;
     28 40 47 7 48; 28 18 47 31 48]
  , Quartile() =>
      [13 1 13 0 0; 22 1 22 0 0; 18 2 17 0 0; 26 2 24 0 0; 18 2 15 2 16;
       24 4 19 0 0; 18 2 14 4 15; 22 4 18 2 19; 20 4 16 4 17; 24 6 19 2 20;
       28 4 22 4 23; 26 4 20 6 21; 24 8 20 4 21; 20 11 16 5 17; 30 5 24 7 25;
       24 15 19 2 20; 28 1 22 15 23; 28 17 22 1 23; 26 17 21 4 22;
       30 15 24 5 25; 28 17 22 6 23; 30 7 24 16 25; 30 11 24 14 25;
       30 11 24 16 25; 30 7 24 22 25; 28 28 22 6 23; 30 8 23 26 24;
       30 4 24 31 25; 30 1 23 37 24; 30 15 24 25 25; 30 42 24 1 25;
       30 10 24 35 25; 30 29 24 19 25; 30 44 24 7 25; 30 39 24 14 25;
       30 46 24 10 25; 30 49 24 10 25; 30 48 24 14 25; 30 43 24 22 25;
       30 34 24 34 25]
  , High() =>
      [17 1 9 0 0; 28 1 16 0 0; 22 2 13 0 0; 16 4 9 0 0; 22 2 11 2 12;
       28 4 15 0 0; 26 4 13 1 14; 26 4 14 2 15; 24 4 12 4 13; 28 6 15 2 16;
       24 3 12 8 13; 28 7 14 4 15; 22 12 11 4 12; 24 11 12 5 13; 24 11 12 7 13;
       30 3 15 13 16; 28 2 14 17 15; 28 2 14 19 15; 26 9 13 16 14;
       28 15 15 10 16; 30 19 16 6 17; 24 34 13 0 0; 30 16 15 14 16;
       30 30 16 2 17; 30 22 15 13 16; 30 33 16 4 17; 30 12 15 28 16;
       30 11 15 31 16; 30 19 15 26 16; 30 23 15 25 16; 30 23 15 28 16;
       30 19 15 35 16; 30 11 15 46 16; 30 59 16 1 17; 30 22 15 41 16;
       30 2 15 64 16; 30 24 15 46 16; 30 42 15 32 16; 30 10 15 67 16;
       30 20 15 61 16]
  )

"""
Remainder bits per version.
"""
const remainderbits = Array{Int, 1}(
    [0, 7, 7, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3,
     4, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0])

"""
Location of the alignment patterns per version.
"""
const alignmentlocation = Array{Array{Int, 1}, 1}(
    [ []
    , [6, 18]
    , [6, 22]
    , [6, 26]
    , [6, 30]
    , [6, 34]
    , [6, 22, 38]
    , [6, 24, 42]
    , [6, 26, 46]
    , [6, 28, 50]
    , [6, 30, 54]
    , [6, 32, 58]
    , [6, 34, 62]
    , [6, 26, 46, 66]
    , [6, 26, 48, 70]
    , [6, 26, 50, 74]
    , [6, 30, 54, 78]
    , [6, 30, 56, 82]
    , [6, 30, 58, 86]
    , [6, 34, 62, 90]
    , [6, 28, 50, 72, 94]
    , [6, 26, 50, 74, 98]
    , [6, 30, 54, 78, 102]
    , [6, 28, 54, 80, 106]
    , [6, 32, 58, 84, 110]
    , [6, 30, 58, 86, 114]
    , [6, 34, 62, 90, 118]
    , [6, 26, 50, 74, 98, 122]
    , [6, 30, 54, 78, 102, 126]
    , [6, 26, 52, 78, 104, 130]
    , [6, 30, 56, 82, 108, 134]
    , [6, 34, 60, 86, 112, 138]
    , [6, 30, 58, 86, 114, 142]
    , [6, 34, 62, 90, 118, 146]
    , [6, 30, 54, 78, 102, 126, 150]
    , [6, 24, 50, 76, 102, 128, 154]
    , [6, 28, 54, 80, 106, 132, 158]
    , [6, 32, 58, 84, 110, 136, 162]
    , [6, 26, 54, 82, 110, 138, 166]
    , [6, 30, 58, 86, 114, 142, 170]
    ]
)

"""
Length of message bits for version 1-40.
"""
const msgbitslen = [208, 359, 567, 807, 1079, 1383, 1568, 1936, 2336, 2768, 
    3232, 3728, 4256, 4651, 5243, 5867, 6523, 7211, 7931, 8683, 9252, 
    10068, 10916, 11796, 12708, 13652, 14628, 15371, 16411, 17483, 18587, 
    19723, 20891, 22091, 23008, 24272, 25568, 26896, 28256, 29648]

"""
    int2bitarray(n::Int)

Encode an integer into a `BitArray`.
"""
function int2bitarray(k::Integer; pad::Int = 8)
    res = BitArray{1}(undef, pad)
    for i in pad:-1:1
        @inbounds res[i] = k & 1
        k >>= 1
    end
    k != 0 && throw("int2bitarray: bit-length of $k is longer than $pad")
    return res
end

"""
    qrversion(fmt::Int)

Encode version information.
"""
function qrversion(ver::Int)
    7 ≤ ver ≤ 40 || throw(InfoError(
       "version code $ver should be no less than 7 and no greater than 40"))
    # error correction code
    err = ver << 12
    # generator polynomial(= 0b1111100100101 in binary)
    g = Int(0x1f25) # use Int(0x1f25) to avoid overflow
    for i in 5:-1:0
        if !iszero(err & (1 << (i + 12)))
            err ⊻= g << i
        end
    end
    return ver << 12 ⊻ err
end
qrversion(ver::Integer) = qrversion(Int(ver))

"""
    qrversionbits(ver)

Get version information bits.

Replacement of the `versioninfo` table.
"""
function qrversionbits(ver)
    vercode = qrversion(ver)
    return @view int2bitarray(vercode, pad = 18)[end:-1:1]
end

"""
Bit modes of the qualities.
"""
const mode2bin = Dict(
    Low() => 0b01,
    Medium() => 0b00,
    Quartile() => 0b11,
    High() => 0b10)

const bin2mode = Dict(val=>key for (key, val) in mode2bin)

"""
    qrformat(fmt::Int)

Generate standard format information (format + error correction + mask).
"""
function qrformat(fmt::Int)
    0 ≤ fmt ≤ 31 || throw(EncodeError(
       "format code $fmt should be no less than 0 and no greater than 31"))
    err = fmt << 10 # error correction code
    g = 0x537 # generator polynomial(= 0b10100110111 in binary)
    for i in 4:-1:0
        if !iszero(err & (1 << (i + 10)))
            err ⊻= g << i
        end
    end
    fmt << 10 ⊻ err ⊻ 0x5412 # mask(= 0b101010000010010 in binary)
end
qrformat(fmt::Integer) = qrformat(Int(fmt)) # to avoid integer overflow

function qrformat(ec::ErrCorrLevel, mask::Int)
    fmt = mode2bin[ec] << 3 ⊻ mask
    return int2bitarray(qrformat(fmt); pad = 15)
end