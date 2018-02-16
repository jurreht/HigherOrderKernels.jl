module HigherOrderKernels

export PolynomialKernel,
       UniformKernel,
       EpanechnikovKernel,
       BiweightKernel,
       TriweightKernel,
       bandwidth,
       kpdf,
       order

using GaussQuadrature

abstract type AbstractKernel{ν} end
struct PolynomialKernel{s,ν} <: AbstractKernel{ν} end
const UniformKernel = PolynomialKernel{0}
const EpanechnikovKernel = PolynomialKernel{1}
const BiweightKernel = PolynomialKernel{2}
const TriweightKernel = PolynomialKernel{3}

order(::Type{T}) where {ν,T<:AbstractKernel{ν}} = ν

const bandwidth_constant_lookup = Dict{Type{T} where T<:AbstractKernel,Float64}()

function bandwidth_constant(k::Type{T}) where {s,ν,T<:PolynomialKernel{s,ν}}
  if haskey(bandwidth_constant_lookup, k)
    return bandwidth_constant_lookup[k]
  end
  R_order = 2 * (2s+2(div(ν,2)-1))
  κ_order = ν + (2s+2(div(ν,2)-1))
  N = div(max(R_order, κ_order) + 2, 2)
  x, w = legendre(N)
  R = sum(w[i] * kernel(k, x[i])^2 for i=1:N)
  κ = sum(w[i] * x[i]^ν * kernel(k, x[i]) for i=1:N)
  C = 2*((sqrt(pi)*factorial(BigInt(ν))^3*R)/(2*ν*factorial(BigInt(2ν))*κ^2))^(1/(2ν+1))
  bandwidth_constant_lookup[k] = Float64(C)
end

bandwidth(k::Type{T}, data) where {ν,T<:AbstractKernel{ν}} =
  bandwidth_constant(k) * std(data) * size(data, 1)^(-1/(2ν+1))

pochhammer(x, n) = iszero(n) ? one(x) : prod(x+j for j=0:n-1)

@generated function kernel(::Type{PolynomialKernel{s,ν}}, u) where {s,ν}
  r = div(ν, 2)
  M_constant = pochhammer(1/2, s+1) / factorial(s)
  M_expr = :((1-u2)^$s*(abs(u) <= 1))
  B_constant = pochhammer(3/2, r-1) * pochhammer(3/2+s, r-1) / pochhammer(s+1, r-1)
  B_coefficients = [(-1)^k * pochhammer(1/2+s+r, k) / (factorial(k) * factorial(r-1-k) * pochhammer(3/2, k)) for k=0:r-1]
  B_expr = Expr(:call, :+, (:($(B_coefficients[r+1])*u2^$r) for r=0:r-1)...)
  expr = Expr(:call, :*, B_constant*M_constant, B_expr, M_expr)
  quote
    $(Expr(:meta, :inline))
    u2 = u^2
    $expr
  end
end

kpdf(k, x, data) = kpdf(k, x, data, bandwidth(k, data))

function kpdf(::Type{T}, x, data, h) where {T<:AbstractKernel}
  sum::Float64 = 0.0
  @simd for y in data
    sum += kernel(T, (y - x) / h)
  end
  sum /= length(data) * h
  return sum
end

end # module
