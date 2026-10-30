"""Errors raised by the MMProps.jl client.

One exception type with a `kind` field:

* `:engine`            — the engine exited non-zero / reported an error
* `:protocol`          — non-JSON or an unexpected envelope
* `:timeout`           — the engine did not finish in time (killed)
* `:binary_not_found`  — the `mmprops` executable could not be located
"""

const ERROR_KINDS = (:engine, :protocol, :timeout, :binary_not_found)

struct MmpropsError <: Exception
    message::String
    kind::Symbol
    op::Union{Nothing,String}
    raw::Any
end

function MmpropsError(message::AbstractString; kind::Symbol = :engine, op = nothing, raw = nothing)
    kind in ERROR_KINDS || throw(ArgumentError("unknown MmpropsError kind $(repr(kind))"))
    return MmpropsError(String(message), kind, op === nothing ? nothing : String(op), raw)
end

function Base.showerror(io::IO, err::MmpropsError)
    print(io, "MmpropsError[", err.kind, "]: ", err.message)
    err.op === nothing || print(io, " (op=", err.op, ")")
end
