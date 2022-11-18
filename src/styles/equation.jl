# Tools for linear equation

"""
    gauss_elimination(A::AbstractMatrix, b::AbstractVector)

Solve the linear equations `Ax=b` by Gauss elimination.
"""
gauss_elimination(A::AbstractMatrix, b::AbstractVector) = gauss_elimination!(copy(A), copy(b))
function gauss_elimination!(A::AbstractMatrix, b::AbstractVector)
    x = gauss_elimination!(A, reshape(b, :, 1))
    reshape(x, :) # convert to vector
end

"""
    gauss_elimination(A::AbstractMatrix, B::AbstractMatrix)

Solve the linear equations `Ax=B` by Gauss elimination.
In particular, `Ax=I` returns the inverse of `A`.
"""
gauss_elimination(A::AbstractMatrix, B::AbstractMatrix) = gauss_elimination!(copy(A), copy(B))
function gauss_elimination!(A::AbstractMatrix, B::AbstractMatrix)
    # check the size of A and B
    m, n = size(A)
    m == n || throw(DimensionMismatch("A must be square"))
    size(B, 1) == m || throw(DimensionMismatch("A and B have different size"))
    # Gauss elimination
    @inbounds for i in 1:n
        # Find the pivot
        pivot = findfirst(!iszero, @view(A[i:end, i]))
        pivot === nothing && throw(ArgumentError("A is singular"))
        pivot += i - 1
        # Swap the pivot row with the current row
        currow = @views divide.(A[pivot, :], A[pivot, i]) # set leading entry to 1
        curval = @views divide.(B[pivot, :], A[pivot, i])
        A[pivot, :] = @view(A[i, :]) # `=` is faster than `.=` in general
        B[pivot, :] = @view(B[i, :])
        A[i, :], B[i, :] = currow, curval
        # Eliminate the current column
        for j in 1:n
            j == i && continue
            # rowⱼ = rowⱼ - Aⱼᵢ * rowᵢ
            if !iszero(A[j, i])    
                B[j, :] .⊻= mult.(A[j, i], curval)
                A[j, :] .⊻= mult.(A[j, i], currow)
            end
        end
    end
    return B
end

"""
    gfinv(A::AbstractMatrix)

Return the inverse of `A` in GF(256).
"""
Polynomial.gfinv(A::AbstractMatrix) = gauss_elimination(A, one(A))

"""
    fillblank( block::AbstractVector{<:Integer}
             , validinds::AbstractVector{<:Integer}
             , necwords::Int)

Use Gauss elimination to fill the blank entries in `block`
with valid indices `misinds`.
"""
function fillblank( block::AbstractVector{<:Integer}
                  , validinds::AbstractVector{<:Integer}
                  , necwords::Int)
    reclen = length(block)
    length(validinds) + necwords == reclen || throw(DimensionMismatch(
        "The number of missing indices must be equal to `necwords`"))
    msglen = reclen - necwords
    G = generator_matrix(eltype(block), msglen, necwords)
    G = @view(G[end:-1:1, end:-1:1]) # rotate by 180 degree
    msg = @views gauss_elimination(G[validinds, :], block[validinds])
    return mult(G, msg) # encode message
end