
const finderpattern =
    BitArray{2}([1 1 1 1 1 1 1;
                 1 0 0 0 0 0 1;
                 1 0 1 1 1 0 1;
                 1 0 1 1 1 0 1;
                 1 0 1 1 1 0 1;
                 1 0 0 0 0 0 1;
                 1 1 1 1 1 1 1])

const alignmentpattern =
    BitArray{2}([1 1 1 1 1;
                 1 0 0 0 1;
                 1 0 1 0 1;
                 1 0 0 0 1;
                 1 1 1 1 1])

function emptymatrix(version::Int64)
    n = (version - 1) * 4 + 21
    matrix = Array{Union{Bool, Nothing}, 2}(nothing, (n, n))

    # Finder Patterns
    matrix[1:7, 1:7] = finderpattern
    matrix[1:7, n-6:n] = finderpattern
    matrix[n-6:n, 1:7] = finderpattern

    # Separators
    matrix[8, 1:8] = zeros(8)
    matrix[8, n-7:n] = zeros(8)
    matrix[n-7, 1:8] = zeros(8)
    matrix[1:8, 8] = zeros(8)
    matrix[n-7:n, 8] = zeros(8)
    matrix[1:8, n-7] = zeros(8)

    # Alignment Location Patterns
    loc = alignmentlocation[version]
    for i in loc, j in loc
        if !( (i-1 < 8 && j-1 < 8)   ||
              (i-1 < 8 && j+3 > n-7) ||
              (i+3 > n-7 && j-1 < 8)    )
            matrix[i-1:i+3, j-1:j+3] = alignmentpattern
        end
    end

    # Timing Patterns
    timing = repeat(BitArray([0, 1]), (n-15)÷2)
    matrix[7, 8:n-8] = timing
    matrix[8:n-8, 7] = timing

    # Format information area + dark module
    matrix[9, 1:9] = ones(9)
    matrix[9, n-7:n] = ones(8)
    matrix[1:9, 9] = ones(9)
    matrix[n-7:n, 9] = ones(8)

    # Version information areas for version 7+
    if version >= 7
        matrix[1:6, n-10:n-8] = ones(6,3)
        matrix[n-10:n-8, 1:6] = ones(3,6)
    end

    return matrix
end

function getpath(matrix::Array{Union{Bool, Nothing}, 2})
    n = size(matrix)[1]
    path = Tuple{Int64, Int64}[]
    col, row = n, n + 1
    while col > 0
        if col == 7
            col -= 1
            continue
        end
        if row > n
            row = n
            δrow = -1
        else
            row = 1
            δrow = 1
        end
        for _ in 1:n
            if isnothing(matrix[row, col])
                push!(path, (row, col))
            end
            if isnothing(matrix[row, col-1])
                push!(path, (row, col-1))
            end
            row += δrow
        end
        col -= 2
    end
    return path
end

function placedata!( matrix::Array{Union{Bool, Nothing}, 2}
                   , path::Array{Tuple{Int64, Int64}, 1}
                   , data::BitArray{1}
                   )
    for (p, b) in zip(path, data)
         matrix[p[1], p[2]] = b
    end
    return BitArray{2}(matrix)
end

function makemasks( matrix::Array{Union{Bool, Nothing}, 2} )
    masks = [falses(size(matrix)) for _ in 1:8]
    n = size(matrix)[1]

    for row in 1:n, col in 1:n
        if !isnothing(matrix[row, col])
            continue
        end
        if (row + col) % 2 == 0
            masks[1][row, col] = true
        end
        if row % 2 == 0
            masks[2][row, col] = true
        end
        if col % 3 == 0
            masks[3][row, col] = true
        end
        if (row + col) % 3 == 0
            masks[4][row, col] = true
        end
        if ((row ÷ 2) + (col ÷ 3)) % 2 == 0
            masks[5][row, col] = true
        end
        if ((row * col) % 2) + ((row * col) % 3) == 0
            masks[6][row, col] = true
        end
        if (((row * col) % 2) + ((row * col) % 3)) % 2 == 0
            masks[7][row, col] = true
        end
        if (((row + col) % 2) + ((row * col) % 3)) % 2 == 0
            masks[8][row, col] = true
        end
    end

    return masks
end

function penalty(matrix::BitArray{2})
    rows, cols = size(matrix)

    # Condition 1: 5+ in a row of the same color
    score(c) = foldl(check , c, init = (0, !c[1], 0))[1]
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
    p1 = sum(map(score, eachrow(matrix))) + sum(map(score, eachcol(matrix)))

    # Condition 2: number of 2x2 blocks of the same color
    p2 = 0
    for row in 1:rows-1, col in 1:cols-1
        block = matrix[row:row+1, col:col+1]
        if all(block) || all(map(!, block))
            p2 += 2
        end
    end

    # Condition 3: specific patterns
    patt1 = BitArray([1, 0, 1, 1, 1, 0, 1, 0, 0, 0 ,0])
    patt2 = BitArray([0, 0, 0 ,0, 1, 0, 1, 1, 1, 0, 1])
    p3 = 0
    for row in 1:rows, col in 1:cols-10
        hline = matrix[row, col:col+10]
        if all(map(!, xor.(hline, patt1))) || all(map(!, xor.(hline, patt2)))
            p3 += 40
        end
        vline = matrix[col:col+10, row]
        if all(map(!, xor.(vline, patt1))) || all(map(!, xor.(vline, patt2)))
            p3 += 40
        end
    end

    # Condition 4: percentage of black and white
    t = (sum(matrix) / length(matrix) * 100) ÷ 5
    p4 = 10 * min(abs(t-10), abs(t-9))

    return p1 + p2 + p3 + p4
end

function addformat(matrix::BitArray{2}, mask::Int64, version::Int64, eclevel::ErrCorrLevel)
    format = formatinfo[(eclevel, mask)]
    n = size(matrix, 1)

    # Top left
    matrix[9, 1:6]    = format[1:6]
    matrix[9, 8:9]    = format[7:8]
    matrix[8, 9]      = format[9]
    matrix[6:-1:1, 9] = format[10:15]

    # bottom and right
    matrix[n:-1:n-6, 9] = format[1:7]
    matrix[9, n-7:n]    = format[8:15]

    if version >= 7
        vinfo = reshape(versioninfo[version], (3, 6))

        matrix[n-10:n-8, 1:6] = vinfo
        matrix[1:6, n-10:n-8] = transpose(vinfo)
    end

    return matrix
end


function render(m)
    f(::Nothing) = false
    f(b::Bool) = b

    return map(f, m)
end

function rendernothing(m)
    f(::Nothing) = true
    f(b::Bool) = false

    return map(f, m)
end

function renderint(m)
    f(::Nothing) = 1
    f(b::Bool) = b ? 0 : 2

    return map(f, m)
end
