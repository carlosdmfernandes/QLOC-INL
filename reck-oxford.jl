# Part of QLOC.jl package

using LinearAlgebra

"""
Eliminate the matrix element at coordinates '(m, n)' by multiplying a beam
splitter.
The beamsplitter pivots on line k if multiplied at the left or
at column k if multiplied at the right.
"""
function elim!(mat, m, n, k, left=true)
    dim = size(mat)[1]
    c = mat[m, n]
    if left
        a = mat[k, n]
        rang = atan(abs(c) , abs(a))
        ph = abs2(a) <= 0.0 ? 0.0 : -angle(c/a)
        bs = BeamSplitter(m, k, ph, rang)
        x!(bs, mat)
    else
        a = mat[m, k]
        rang = atan(abs(c) , abs(a))
        ph = abs2(a) <= 0.0 ? 0.0 : angle(-c/a)
        bs = BeamSplitter(k, n, ph, rang, true)
        x!(mat, bs)
    end
    return bs
end

"Represents a unitary matrix in Oxford decomposed form."
struct OxfordDecomp
    bsvec::Vector{BeamSplitter}
    diag::Vector{ComplexF64}
end

"""
`OxfordDecomp(mat::Matrix{T<:Number})`

Return an OxfordDecomp object giving the oxford decomposition of
a unitary matrix `mat`.
"""
function OxfordDecomp(mat::Matrix{<:Number})
    resmat = Matrix{ComplexF64}(mat)
    bsvec = oxford!(resmat)
    matdiag = diag(resmat)
    OxfordDecomp(bsvec, matdiag)
end

Matrix(od::OxfordDecomp) = compose!(od.bsvec, collect(Diagonal(od.diag)))

#left kills with lines; right with columns
"
Decompose the matrix using the Oxford decomposition as in the article
(*cite article here*)
This function transforms a unitary matrix into a unitary diagonal matrix.
It returns an array of the beam spillters used to decompose the matrix.
"
function oxford!(mat::AbstractMatrix)
    n = size(mat)[1]
    bsplitters = BeamSplitter[]
    left = false
    x = 1
    y = 1
    dir = 1
    while x<n && y<n
        # eliminate entries in the lower triangle in "zigzag" order.
        pivot = left ? n-x : y+1
        bs = elim!(mat, n-x+1, y, pivot, left)
        push!(bsplitters, bs)
        x += dir
        y -= dir
        if x == 0
            x = 1
            dir *= -1
            left = !left
        elseif y == 0
            y = 1
            dir *= -1
            left = !left
        end
    end
    return bsplitters
end

"
Compose an interferometer with beam splitters and phase shifters according to
the Oxford prescription. Inverts the Oxford! function if given its output as the
arguments.
"
function compose!(array::Vector{BeamSplitter}, matrix)
    for j in Iterators.reverse(array)
        j.transposed ? x!(matrix, inv(j)) : x!(inv(j), matrix)
    end
    matrix
end

"Compose an array without overwriting it."
function compose(array::Vector{BeamSplitter}, matrix)
    result = copy(matrix)
    compose!(array, result)
end

function compose(array::Vector{BeamSplitter})
    dim = max([max(i.n, i.m) for i in array])
    matrix = Matrix{ComplexF64}(I, dim, dim)
    compose!(array, matrix)
end

"
Builds an array of beam splitters according to the Oxford construction
from an array of parameter variables.
Intended for use with the optimize function of the Optims.jl package.
"
function oxfordarray(bsphases, bsmixing, dim)
    nsplits = div(dim*(dim-1), 2)
    vector = Vector{BeamSplitter}(undef, nsplits)
    left = false
    x = 1
    y = 1
    dir = 1
    i = 1
    while x<dim && y<dim
        # eliminate entries in the lower triangle in "zigzag" order.
        if left
            bs = BeamSplitter(dim-x+1, dim-x, bsphases[i], bsmixing[i])
        else
            bs = BeamSplitter(y+1, y,  bsphases[i], bsmixing[i], true)
        end
        vector[i] = bs
        x += dir
        y -= dir
        i += 1
        if x == 0
            x = 1
            dir *= -1
            left = !left
        elseif y == 0
            y = 1
            dir *= -1
            left = !left
        end
    end
    return vector
end
