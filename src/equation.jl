# Gauss elimination

import .Polynomial: mult, divide, gfinv
function gauss_elimination!(A::AbstractMatrix, b::AbstractVector)
    (n = size(A, 1)) == length(b) || throw(DimensionMismatch("A and b have different size"))
    for i in 1:(n-1)
        # Find the pivot
        pivot = findfirst(!iszero, @view(A[i:end, i]))
        pivot === nothing && throw(ArgumentError("A is singular"))
        pivot += i - 1
        # Swap the pivot row with the current row
        A[[i, pivot], :] .= A[[pivot, i], :] # @view could bring errors
        b[[i, pivot]] .= b[[pivot, i]]
        # Eliminate the current column
        lt = A[i, i]
        for j in (i + 1):n
            if !iszero(A[j, i])
                fac = divide(A[j, i], lt)
                A[j, :] .⊻= @views mult.(A[i, :], fac)
                b[j] ⊻= mult(b[i], fac)
            end
        end
    end
    iszero(A[n, n]) && throw(ArgumentError("A is singular"))
    return A, b
end
gauss_elimination(A::AbstractMatrix, b::AbstractVector) = gauss_elimination!(copy(A), copy(b))
function gauss_elimination(A::AbstractMatrix, b::AbstractMatrix)
    # though it is not necessary, we require b to be a vector
    size(b, 2) == 1 || throw(DimensionMismatch("b must be a vector"))
    return gauss_elimination(A, b[:, 1])
end

# Solve a linear system of equations
function solve(A::AbstractMatrix, b::AbstractVector)
    (n = size(A, 1)) == length(b) || throw(DimensionMismatch("A and b have different size"))
    A, b = gauss_elimination(A, b)
    x = zeros(eltype(b), n)
    for i in n:-1:1
        x[i] = divide(b[i], A[i, i])
        for j in 1:(i-1)
            b[j] ⊻= mult(A[j, i], x[i])
        end
    end
    return x
end
function solve(A::AbstractMatrix, b::AbstractMatrix)
    size(b, 2) == 1 || throw(DimensionMismatch("b must be a vector"))
    return solve(A, @view(b[:, 1]))
end

# matrix multiplication
function mult(A::AbstractMatrix, B::AbstractMatrix)
    (n, m), (p, q) = size(A), size(B)
    m == p || throw(DimensionMismatch("A and B have different size"))
    C = Array{eltype(A)}(undef, n, q)
    for i in 1:n, j in 1:q
        C[i, j] = @views reduce(xor, mult.(A[i, :], B[:, j]))
    end
    return C
end
function mult(A::AbstractMatrix, b::AbstractVector)
    (n, m) = size(A)
    m == length(b) || throw(DimensionMismatch("A and b have different size"))
    c = zeros(eltype(b), n)
    for i in 1:n
        c[i] = @views reduce(xor, mult.(A[i, :], b))
    end
    return c
end