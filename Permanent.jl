using LinearAlgebra

#multPow2(n, m) = n << m
#remPow2(n, m) = n & (multPow2(2, m)-1)
"Implement (-1)^x more efficently."
partosign(x) = 1 - ((x & 1 ) << 1)

"Convert a binary number n to its Gray code representation."
bitToGray(n) = n ⊻ (n>>>1)

"Find the bit flipped in Gray code when going from n-1 to n."
function grayBitToFlip(n::Integer)
	n1 = bitToGray(n)
	n2 = bitToGray(n-1)
	d = n1 ⊻ n2 #find the position of the flip
	sign = partosign(iszero(n1 & d)) #equivalent to (-1)^sign
	j = trailing_zeros(d) + 1
	return j, sign
end


"""
function grayBitToFlip2(n::Integer)
	n1 = bitToGray(n)
	n2 = bitToGray(n-1)
	d = n1 ⊻ n2 #find the position of the flip
	sign = 1 - ((iszero(n1 & d)  & 1 ) << 1) #equivalent to (-1)^sign
	j = 0
	while d != 0
		d >>>= 1
		j += 1
	end
	return j, sign
end

Alternative implementation of grayBitToFlip roughly 1.5 times slower

function decompose(number::Integer)
    pos = 0
    x = number
    while true
        x, i = x >>> 1, Bool(x & 1) #equivalent to x,i= divrem(x, 2)
        pos+=1
		if i
			sign = 1 - ((x & 1 ) << 1)
			return pos, sign
		end
	end
end
"""

"Best Optimized implementation of the Permanent"
function permanent(matrix, ::Val{c}) where {c}
	T = eltype(matrix)
    length = c ? big(size(matrix,1)) : size(matrix,1)
    column = zeros(T,length)
    total = zero(T)
	par=1
    for i in 1:(2^length-1)
		par *= -1
        pos, sign = grayBitToFlip(i)
        LinearAlgebra.axpy!(sign,view(matrix,:,pos), column)
        #column += sign*view(matrix, :, pos)
        total += par*prod(column)
    end
    total = total*partosign(length)
    return total
end

permanent(matrix) = permanent(matrix, Val(false))
mydiv(a::Integer, b::Integer) = div(promote(a,b)...)
mydiv(a, b) = a/b

"Permanent by Glynn's formula. Could still be optimized."
function gpermanent(matrix, ::Val{c}) where {c}
    lenfac = c ? 2^big(size(matrix,1)-1) : 2^(size(matrix,1)-1)
	column = sum(matrix, dims=2) #optimize to major order
    total = prod(column)
	par = 1
    for i in 1:(lenfac-1)
		par *= -1
        pos, sign = grayBitToFlip(i)
		fac = -2*sign
        LinearAlgebra.axpy!(fac, view(matrix,:,pos), column)
        #column += sign*view(matrix, :, pos)
        total += par*prod(column)
    end
    total = mydiv(total, lenfac)
    return total
end

gpermanent(matrix) = gpermanent(matrix, Val(false))

"Find the next flip in generalized gray code for an hyperparalelogram."
function multiGrayBitToFlip(x, vector=ones(Int, 64))
    for (pos, n) in enumerate(vector)
		rem = x%(n+1)
		if rem != 0
			par = div(x,n+1) & 1
			sign = partosign(par)
			start = par*n + sign*(rem-1)
            return pos, sign, start
        end
        x = div(x,n+1)
    end
	throw(DomainError(x))
end

#----The code below is untested----

"Calculate the factor in the next iteration
of the generalized Glyyn's formula."
cfac(i, n, sign) = cis(2*pi*i/(n+1))*expm1(2*pi*im*sign/(n+1))

"Calculate the permanent with repeated lines and columns according to the
generalized Glynn's Formula"
function gmultipermanent(matrix::AbstractMatrix{<:Complex}, fvector)
	length = size(matrix,1)
    column = sum(matrix, dims=2) #optimize to major order
    total = prod(column)
	prodfac = prod(fvector .+ 1)
	rootfac = one(eltype(matrix))
    for i in 1:(prodfac-1)
        pos, sign, val = multiGrayBitToFlip(i, fvector)
		rootmult = fvector[pos]
		rootfac *= cis(2*pi*sign/(rootmult+1))
		fac = cfac(val, rootmult, sign)
        LinearAlgebra.axpy!(fac, view(matrix, :, pos), column)
        #column += sign*view(matrix, :, pos)
        total += rootfac*prod(column)
    end
    total = total/prodfac
    return total
end

function gmultipermanent(matrix::AbstractMatrix{<:Complex}, fvector, yvector)
	length = size(matrix,1)
    column = sum(matrix, dims=2) #optimize to major order
    total = prod(column .^ yvector)
	prodfac = prod(fvector .+ 1)
	rootfac = one(eltype(matrix))
    for i in 1:(prodfac-1)
        pos, sign, val = multiGrayBitToFlip(i, fvector)
		rootmult = fvector[pos]
		rootfac *= cis(2*pi*sign/(rootmult+1))
		fac = cfac(val, rootmult, sign)
        LinearAlgebra.axpy!(fac, view(matrix, :, pos), column)
        #column += sign*view(matrix, :, pos)
        total += rootfac*prod(column .^ yvector)
    end
    total = total/prodfac
    return total
end

gmultipermanent(matrix, args...) = gmultipermanent(ComplexF64.(matrix), args...)
gmultipermanent(matrix) = gmultipermanent(matrix, ones(Int, size(matrix,1)))

"Calculate the permanent with multiple lines and columns by the modified Ryser's
Formula."
function rmultipermanent(matrix::AbstractMatrix, fvector, yvector, ::Val{false})
	T = eltype(matrix)
	length = size(matrix,1)
    column = zeros(T, length)
    total = zero(T)
	par = 1
	fac = 1
	prodfac = prod(fvector .+ 1)
    for i in 1:(prodfac-1)
		par *= -1
        pos, sign, val = multiGrayBitToFlip(i, fvector)
		n = fvector[pos]
		k = div(1 - sign, 2)*n + sign*val
		fac = div((n - k)*fac, k + 1)
        LinearAlgebra.axpy!(sign, view(matrix, :, pos), column)
        #column += sign*view(matrix, :, pos)
        total += par*fac*prod(column .^ yvector)
    end
    total = total*partosign(length)
    return total
end

"The same as above, but employing arbitrary precision integers, in case of
overflow."
function rmultipermanent(matrix::AbstractMatrix, fvector, yvector, ::Val{true})
	length = size(matrix,1)
	T = big(eltype(matrix))
	column, total = zeros(T, length), zero(T)
	fac, prodfac = BigInt(1), prod(fvector .+ 1)
	par = 1
    for i in 1:(prodfac-1)
		par *= -1
        pos, sign, val = multiGrayBitToFlip(i, fvector)
		n = fvector[pos]
		k = div(1 - sign, 2)*n + sign*val
		fac = div((n - k)*fac, k + 1)
		#println(log2(fac)) Everything is okay.
        LinearAlgebra.axpy!(sign, view(matrix, :, pos), column)
        #column += sign*view(matrix, :, pos)
		product = prod(column .^ yvector)
        total += par*fac*product
    end
    total = total*partosign(length)
    return total
end

"Make it default to machine integers because its faster."
rmultipermanent(matrix::AbstractMatrix, fvector, yvector; B::Bool=false) =
	rmultipermanent(matrix::AbstractMatrix, fvector, yvector, Val(B))

"Default to the permanent if there is no information
about line and column repetitions."
rmultipermanent(matrix) = rmultipermanent(matrix,
                                          ones(Int, size(matrix,1)),
                                          ones(Int, size(matrix,1))
                                          )
