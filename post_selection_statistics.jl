using Statistics
include("Permanent.jl")

"Contains tools for statistical analysis of post-selected nonlinear optical
processes with special attention to merit functions."

"Calculate the success transition amplitude for n input photons
for a given unitary matrix."
function psamplitude(matrix, nphotons)
    dim = size(matrix)[1]
    a = ones(Int, dim)
    a[1] = nphotons
    rmultipermanent(matrix, a, a)/factorial(nphotons)
end

"Generate the matrix relating the polynomial coefficients
to the generated angles."
Lmat(n) = [i^j for i=0:n, j=0:n]

"Calculate the coefficients given a list of angles."
function anglestocoefs(angles)
    n=length(angles) - 1
    inv(Lmat(n))*angles
end

"Calculate amplitudes of the interfermeter up to n photons."
nsamplitudes(matrix, n) = [psamplitude(matrix, i) for i in 0:n]

merit(array, key, args...) = get(MERIT_DICTS, key, nothing)(array, args)

"Qunatify how far amplitudes are form having equal absolute value by
adding the absolute value of the difference of absolute value from the first element."
merit_probdiffs(parray) =  sum( abs.( abs.(parray[2:end]) .- abs(parray[1]) ) )#jl arrays start at 1

"Qunatify how far the amplitudes are from having equal absolute value by
calculating the standard deviation of the absolute value."
merit_stddev(parray) = std(abs.(parray), corrected=false)

"Calculate a merit function that favours large mean values."
merit_lprob(parray, c=1.) = merit_stddev(parray) + c*(1-mean(parray))^2

"Calculate a merit function favouring a small 'nangle' angle."
function merit_centre(parray, c=1., d=1., nangle=2)
    phases = angle.(parray)
    angle = anglestocoefs(phases)[nangle]
    merit_lprob(parray, c) + d*sin(angle)^2
end

"Calculate a merit function favouring a large 'nangle' angle."
function merit_sides(parray, c=1., d=1., nangle=2)
    phases = angle.(parray)
    angle = anglestocoefs(phases)[nangle]
    merit_lprob(parray, c) + d*cos(angle)^2
end

"Calculate a merit function favouring the value phiangle for some 'nangle' angle."
function merit_angle(parray, phiangle, c=1., d=1.,nangle=2)
    phases = angle.(parray)
    angle = anglestocoefs(phases)[nangle]
    merit_lprob(parray, c) + d*sin(angle-phiangle)^2
end

"Calculate a merit function that weighs variance exponentially.
(and hopefully priotizes its minimization above other parameters.)."
function merit_exp(parray, a=1., c=1.)
    variance = var(abs.(parray), corrected=false)
    expm1(a*var) + c*(1-mean(parray))^2
end

MERIT_DICTS = Dict(
    "probdiffs" => merit_probdiffs,
    "stddev" => merit_stddev,
    "lprob" => merit_lprob,
    "centre" => merit_centre,
    "center" => merit_centre,
    "sides" => merit_sides,
    "angle" => merit_angle,
    "exp" => merit_exp,
    )

#reduced_form(functon, n, args..) = x -> function(matrix_form(x,n), args...)