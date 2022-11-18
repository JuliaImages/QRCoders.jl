# Test for Gauss elimination
function fillblankbyFA( block::AbstractVector{<:Integer}
                      , misinds::AbstractVector{<:Integer}
                      , necwords::Int)
    n = length(block) # number of bytes
    recpoly = Poly(reverse(block))
    orgpoly = fillerasures!(recpoly, n .- misinds, necwords)
    return @view(orgpoly.coeff[end:-1:1])
end

@testset "Fill blank -- Gauss elimination vs Forney algorithm" begin
    # test for fillblank
    msglen = rand(1:100)
    necwords = rand(1:255 - msglen)
    reclen = msglen + necwords
    block = rand(0:255, reclen)
    validinds = sample(1:msglen, msglen, replace=false)
    misinds = setdiff(1:reclen, validinds)
    # Note that Gauss elimination takes O(N^3)
    # while Forney Algorithm takes O(N^2)
    validblock = fillblank(block, validinds, necwords)
    blockbyFA = fillblankbyFA(block, misinds, necwords)
    @test validblock == blockbyFA
    @test validblock[validinds] == block[validinds]
    # test for UInt8
    msglen = rand(1:100)
    necwords = rand(1:255 - msglen)
    reclen = msglen + necwords
    block = rand(UInt8, reclen)
    validinds = sample(1:msglen, msglen, replace=false)
    misinds = setdiff(1:reclen, validinds)
    validblock = fillblank(block, validinds, necwords)
    blockbyFA = fillblankbyFA(block, misinds, necwords)
    @test validblock == blockbyFA
    @test validblock[validinds] == block[validinds]
end

## use Gauss elimination to find the inverse of the matrix
@testset "Generator matrix -- inverse of submatrix" begin
    # Test for matrix inverse
    ## Int
    A = [1 2 3; 4 5 6; 7 8 9]
    A1 = gfinv(A)
    @test mult(A, A1) |> isone
    A = [1 2 3; 4 5 6; 5 7 9] # note that this matrix is invertible in GF(256)
    A1 = gfinv(A)
    @test mult(A, A1) |> isone
    ## UInt8
    A = UInt8[1 2 3; 4 5 6; 7 8 9]
    A1 = gfinv(A)
    @test mult(A, A1) |> isone
    ## test throw
    @test_throws ArgumentError gfinv([1 2; 1 2])
    A = [1 2 3; 4 5 6; 7 8 9]
    A[3, :] = A[1, :] .⊻ A[2, :]
    @test_throws ArgumentError gfinv(A)
    ## any `msglen` rows of a generator matrix are linearly dependent
    msglen = 3
    necwords = 5
    reclen = msglen + necwords
    A = generator_matrix(msglen, necwords)
    rows = sample(1:reclen, msglen, replace=false)
    @test mult(gfinv(A[rows, :]), A[rows, :]) |> isone
    
    necwords, _, msglen = getecinfo(1, Medium())
    A = generator_matrix(msglen, necwords)
    rows = sample(1:msglen + necwords, msglen, replace=false)
    @test mult(gfinv(A[rows, :]), A[rows, :]) |> isone
    ### random test
    for eclevel in eclevels, v in 1:40
        necwords, _, msglen, _, msglen2 = getecinfo(v, eclevel)
        A = generator_matrix(msglen, necwords)
        rows = sample(1:msglen + necwords, msglen, replace=false)
        @test mult(gfinv(A[rows, :]), A[rows, :]) |> isone
        A = generator_matrix(msglen2, necwords)
        rows = sample(1:msglen2 + necwords, msglen2, replace=false)
        @test mult(gfinv(A[rows, :]), A[rows, :]) |> isone
    end

end

@testset "Linear equations" begin
    A = [1 2 3; 4 5 6; 7 8 9]
    b = [1, 2, 3]
    x = gauss_elimination(A, b)
    @test mult(A, x) == b
    b = reshape([1, 2, 3], :, 1)
    x = gauss_elimination(A, b)
    @test mult(A, x) == b
    B = rand(0:255, 3, rand(1:10))
    x = gauss_elimination(A, B)
    @test mult(A, x) == B
end
