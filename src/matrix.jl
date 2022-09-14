# Manipulations for creating the QR code matrix

"""
Finder patterns in the corners of QR codes.
"""
const finderpattern =
    BitArray{2}([1 1 1 1 1 1 1;
                 1 0 0 0 0 0 1;
                 1 0 1 1 1 0 1;
                 1 0 1 1 1 0 1;
                 1 0 1 1 1 0 1;
                 1 0 0 0 0 0 1;
                 1 1 1 1 1 1 1])

"""
Alignment pattern in the center of large QR codes.
"""
const alignmentpattern =
    BitArray{2}([1 1 1 1 1;
                 1 0 0 0 1;
                 1 0 1 0 1;
                 1 0 0 0 1;
                 1 1 1 1 1])

"""
    emptymatrix(version::Int)

Return a matrix for the QR code filled with data-independent elements. `nothing`
matrix elements act as a placeholder for the data.
"""
function emptymatrix(version::Int)::Array{Union{Bool,Nothing},2}
    n = (version - 1) * 4 + 21
    # nothing is used as a placeholder for the data
    matrix = Array{Union{Bool,Nothing},2}(nothing, (n, n))

    # Finder Patterns
    matrix[1:7, 1:7]     = finderpattern
    matrix[1:7, n - 6:n] = finderpattern
    matrix[n - 6:n, 1:7] = finderpattern

    # Separators around the finder patterns
    matrix[8, 1:8]     .= 0
    matrix[8, n - 7:n] .= 0
    matrix[n - 7, 1:8] .= 0
    matrix[1:8, 8]     .= 0
    matrix[n - 7:n, 8] .= 0
    matrix[1:8, n - 7] .= 0

    # Alignment Location Patterns
    loc = alignmentlocation[version]
    for i in loc, j in loc
        if !( (i - 1 < 8 && j - 1 < 8)   ||
              (i - 1 < 8 && j + 3 > n - 7) ||
              (i + 3 > n - 7 && j - 1 < 8)    )
            matrix[i - 1:i + 3, j - 1:j + 3] = alignmentpattern
        end
    end

    # Timing Patterns
    timing = repeat(BitArray([0, 1]), (n - 15) ÷ 2)
    matrix[7, 8:n - 8] = timing
    matrix[8:n - 8, 7] = timing

    # Format information area + dark module
    matrix[9, 1:9]     .= 1
    matrix[9, n - 7:n] .= 1
    matrix[1:9, 9]     .= 1
    matrix[n - 7:n, 9] .= 1

    # Version information areas for version 7+
    if version >= 7
        matrix[1:6, n - 10:n - 8] .= 1
        matrix[n - 10:n - 8, 1:6] .= 1
    end

    return matrix
end

"""
    placedata!( matrix::Array{Union{Bool,Nothing},2}, data::BitArray{1})

Fill the matrix with the data.
"""
function placedata!( matrix::Array{Union{Bool,Nothing},2}
                   , data::BitArray{1}
                   )::BitArray{2}
    n = size(matrix, 1)
    col, row, ind = n, n + 1, 1
    while col > 0
        # Skip the column with the timing pattern
        if col == 7
            col -= 1
            continue
        end

        # path goes up and down
        if row > n
            row, δrow = n, -1
        else
            row, δrow = 1, 1
        end

        # place data if matrix element is nothing
        for _ in 1:n
            if isnothing(matrix[row, col])
                matrix[row, col] = data[ind]
                ind += 1
            end
            if isnothing(matrix[row, col - 1])
                matrix[row, col - 1] = data[ind]
                ind += 1
            end
            row += δrow
        end
        # go left
        col -= 2
    end
    ind > length(data) || throw(EncodeError("not all data was placed"))
    return BitArray{2}(matrix)
end

_maskrules = [
    (x, y) -> (x ⊻ y) & 1,
    (x, _) -> x & 1,
    (_, y) -> y % 3,
    (x, y) -> (x + y) % 3,
    (x, y) -> (x >> 1 + y ÷ 3) & 1,
    (x, y) -> (x & y & 1) + (x * y % 3),
    (x, y) -> (x & y & 1 + x * y % 3) & 1,
    (x, y) -> ((x ⊻ y & 1) + (x * y % 3)) & 1
]
makemask(matrix::AbstractArray, k::Int)::BitArray{2} = makemask(matrix, _maskrules[k])
function makemask(matrix::AbstractArray, rule::Function)::BitArray{2}
    n = size(matrix, 1)
    mask = falses(size(matrix))
    for row in 1:n, col in 1:n
        if isnothing(matrix[row, col]) && iszero(rule(row - 1, col - 1))
            mask[row, col] = true
        end
    end
    return mask
end

"""
    makemasks(matrix::AbstractArray)

Create 8 bitmasks for a given matrix.
"""
makemasks(matrix::AbstractArray) = makemask.(Ref(matrix), 1:8)

"""
    penalty(matrix::BitArray{2})

Calculate a penalty score in order to pick the best mask.
"""
function penalty(matrix::BitArray{2})
    n = size(matrix, 1)
    # Condition 1: 5+ in a row of the same color
    function penalty1(line)
        consecutive, score, cur = 0, 0, -1
        for i in line
            if i == cur
                consecutive += 1
            else
                if consecutive ≥ 5
                    score += consecutive - 2
                end
                consecutive, cur = 1, i
            end
        end
        return score
    end
    p1 = sum(penalty1, eachrow(matrix)) + sum(penalty1, eachcol(matrix))

    # Condition 2: number of 2x2 blocks of the same color
    p2 = 3 * count(matrix[i, j] == matrix[i+1, j] == matrix[i, j+1] ==
                   matrix[i+1, j+1] for i in 1:n-1 for j in 1:n-1)

    # Condition 3: specific patterns in rows or columns
    patt1 = BitArray([1, 0, 1, 1, 1, 0, 1, 0, 0, 0 ,0])
    patt2 = BitArray([0, 0, 0 ,0, 1, 0, 1, 1, 1, 0, 1])
    function check(i, j)
        hline = @view(matrix[i, j:j + 10])
        vline = @view(matrix[j:j + 10, i])
        return (hline == patt1 || hline == patt2) + (vline == patt1 || vline == patt2)
    end
    p3 = 40 * sum(check(i, j) for i in 1:n for j in 1:(n-10))
    
    # Condition 4: percentage of black and white
    t = sum(matrix) * 100 ÷ length(matrix) ÷ 5
    p4 = 10 * min(abs(t - 10), abs(t - 11))

    return p1 + p2 + p3 + p4
end

"""
    addversion!(matrix::BitArray{2}, version::Int)

Add version information bits.
"""
function addversion!(matrix::BitArray{2}, version::Int)
    # version information for version 7+
    if version ≥ 7
        vbits = int2bitarray(qrversion(version); pad=18)
        vinfo = reshape(vbits, (3, 6))
        matrix[end - 10 : end - 8, 1:6] = vinfo
        matrix[1:6, end - 10 : end - 8] = transpose(vinfo)
    end

    return matrix
end

"""
    addformat!(matrix::BitArray{2}, mask::Int, eclevel::ErrCorrLevel)

Add format information bits.
"""
function addformat!(matrix::BitArray{2}, mask::Int, eclevel::ErrCorrLevel)
    # format information bits
    fmt = mode2bin[eclevel] << 3 ⊻ mask
    formatbits = int2bitarray(qrformat(fmt); pad=15)

    # Info around the top left finder pattern
    matrix[9, 1:6]    = @view formatbits[1:6]
    matrix[9, 8:9]    = @view formatbits[7:8]
    matrix[8, 9]      = formatbits[9]
    matrix[6:-1:1, 9] = @view formatbits[10:15]

    # Info around the bottom and right finder pattern
    matrix[end:-1:end - 6, 9] = @view formatbits[1:7]
    matrix[9, end - 7:end]    = @view formatbits[8:15]

    return matrix
end
