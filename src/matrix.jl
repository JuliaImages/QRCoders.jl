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
    emptymatrix(version::Int64)

Return a matrix for the QR code filled with data-independent elements. `nothing`
matrix elements act as a placeholder for the data.
"""
function emptymatrix(version::Int64)::Array{Union{Bool,Nothing},2}
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
    col, row = n, n + 1
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
                matrix[row, col] = popfirst!(data)
            end
            if isnothing(matrix[row, col - 1])
                matrix[row, col - 1] = popfirst!(data)
            end
            row += δrow
        end
        # go left
        col -= 2
    end

    return BitArray{2}(matrix)
end

"""
    makemasks(matrix::Array{Union{Bool,Nothing},2})

Create 8 bitmasks for a given matrix.
"""
function makemasks(matrix::Array{Union{Bool,Nothing},2})::Array{BitArray{2},1}
    n = size(matrix, 1)
    masks = [falses(size(matrix)) for _ in 1:8]

    # Weird indexing due to 0-based indexing in documentation
    for row in 0:n-1, col in 0:n-1
        if !isnothing(matrix[row+1, col+1])
            continue
        end
        if (row + col) % 2 == 0
            masks[1][row+1, col+1] = true
        end
        if row % 2 == 0
            masks[2][row+1, col+1] = true
        end
        if col % 3 == 0
            masks[3][row+1, col+1] = true
        end
        if (row + col) % 3 == 0
            masks[4][row+1, col+1] = true
        end
        if ((row ÷ 2) + (col ÷ 3)) % 2 == 0
            masks[5][row+1, col+1] = true
        end
        if ((row * col) % 2) + ((row * col) % 3) == 0
            masks[6][row+1, col+1] = true
        end
        if (((row * col) % 2) + ((row * col) % 3)) % 2 == 0
            masks[7][row+1, col+1] = true
        end
        if (((row + col) % 2) + ((row * col) % 3)) % 2 == 0
            masks[8][row+1, col+1] = true
        end
    end

    return masks
end

"""
    penalty(matrix::BitArray{2})

Calculate a penalty score in order to pick the best mask.
"""
function penalty(matrix::BitArray{2})::Int64
    rows, cols = size(matrix)

    # Condition 1: 5+ in a row of the same color
    score(c) = foldl(check, c, init = (0, !c[1], 0))[1]
    function check((tot, pb, cnt), b)
        if pb != b
            return (tot, b, 1)
        elseif cnt < 4
            return (tot, b, cnt + 1)
        elseif cnt == 4
            return (tot + 3, b, cnt + 1)
        else
            return (tot + 1, b, cnt)
        end
    end
    if VERSION < v"1.1"
        p1 = sum(score(matrix[i, :]) for i in axes(matrix, 1))
           + sum(score(matrix[:, i]) for i in axes(matrix, 2))
    else
        p1 = sum(map(score, eachrow(matrix)))
           + sum(map(score, eachcol(matrix)))
    end

    # Condition 2: number of 2x2 blocks of the same color
    p2 = 0
    for row in 1:rows - 1, col in 1:cols - 1
        block = matrix[row:row + 1, col:col + 1]
        if all(block) || all(.! block)
            p2 += 2
        end
    end

    # Condition 3: specific patterns in rows or columns
    p3 = 0
    patt1 = BitArray([1, 0, 1, 1, 1, 0, 1, 0, 0, 0 ,0])
    patt2 = BitArray([0, 0, 0 ,0, 1, 0, 1, 1, 1, 0, 1])
    for row in 1:rows, col in 1:cols - 10
        hline = matrix[row, col:col + 10]
        if all(.! xor.(hline, patt1)) || all(.! xor.(hline, patt2))
            p3 += 40
        end

        vline = matrix[col:col + 10, row]
        if all(.! xor.(vline, patt1)) || all(.! xor.(vline, patt2))
            p3 += 40
        end
    end

    # Condition 4: percentage of black and white
    t = (sum(matrix) / length(matrix) * 100) ÷ 5
    p4 = 10 * min(abs(t - 10), abs(t - 9))

    return p1 + p2 + p3 + p4
end

"""
    addformat(matrix::BitArray{2}, mask::Int64, version::Int64, eclevel::ErrCorrLevel)

Add information about the `version` and mask number in `matrix`.
"""
function addformat( matrix::BitArray{2}
                  , mask::Int64
                  , version::Int64
                  , eclevel::ErrCorrLevel)::BitArray{2}

    format = formatinfo[(eclevel, mask)]
    n = size(matrix, 1)

    # Info around the top left finder pattern
    matrix[9, 1:6]    = format[1:6]
    matrix[9, 8:9]    = format[7:8]
    matrix[8, 9]      = format[9]
    matrix[6:-1:1, 9] = format[10:15]

    # Info around the bottom and right finder pattern
    matrix[n:-1:n - 6, 9] = format[1:7]
    matrix[9, n - 7:n]    = format[8:15]

    # Extra version information for version 7+
    if version >= 7
        vinfo = reshape(versioninfo[version], (3, 6))

        matrix[n - 10 : n - 8, 1:6] = vinfo
        matrix[1:6, n - 10 : n - 8] = transpose(vinfo)
    end

    return matrix
end
