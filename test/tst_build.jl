function oldmasks(matrix::Array{Union{Bool,Nothing},2})::Array{BitArray{2},1}
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

@testset "test masks" begin
    tag = true
    for v in 1:40, mask in 1:8
        matrix = emptymatrix(v)
        if makemasks(matrix) != oldmasks(matrix)
            tag = false
            break
        end
    end
    @test tag
end