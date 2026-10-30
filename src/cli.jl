"""One-shot wrappers over the `mmprops` command line (public surface)."""

struct PropertyResult
    fluid::String
    values::Dict{String,Union{Nothing,Float64}}
    units::Dict{String,String}
    raw::Dict{String,Any}
end

struct VleResult
    components::Vector{String}
    kind::String
    converged::Bool
    status::String
    t::Float64
    p::Float64
    x::Vector{Float64}
    y::Vector{Float64}
    rho_l::Union{Nothing,Float64}
    rho_v::Union{Nothing,Float64}
    raw::Dict{String,Any}
end

struct EnvelopeResult
    components::Vector{String}
    rows::Vector{Dict{String,Any}}
    raw::Dict{String,Any}
end

"""
    props(fluid, t, p; data=nothing, binary=nothing, timeout=120.0)

State-point properties (rho / h / s / cp / cv / w / m).
"""
function props(fluid, t, p; data = nothing, binary = nothing, timeout = 120.0)
    args = _base("props", binary, data)
    append!(args, ["--fluid", _name(fluid, "fluid"), "--t", _quantity(t, "t"),
                   "--p", _quantity(p, "p"), "--format", "json"])
    return _property(_json(args, "props", timeout))
end

"""Saturation state at T (psat / rho_l / rho_v / hfg)."""
function sat(fluid, t; data = nothing, binary = nothing, timeout = 120.0)
    args = _base("sat", binary, data)
    append!(args, ["--fluid", _name(fluid, "fluid"), "--t", _quantity(t, "t"),
                   "--format", "json"])
    return _property(_json(args, "sat", timeout))
end

"""Flash at p,h or p,s; exactly one of `h` / `s` is required."""
function flash(fluid; p, h = nothing, s = nothing, data = nothing, binary = nothing, timeout = 120.0)
    ((h === nothing) == (s === nothing)) &&
        throw(ArgumentError("flash needs exactly one of h=... or s=..."))
    spec = h === nothing ? "ps" : "ph"
    args = _base("flash", binary, data)
    append!(args, ["--fluid", _name(fluid, "fluid"), "--spec", spec,
                   "--p", _quantity(p, "p"), "--format", "json"])
    if h === nothing
        append!(args, ["--s", _quantity(s, "s")])
    else
        append!(args, ["--h", _quantity(h, "h")])
    end
    return _property(_json(args, "flash", timeout))
end

"""Binary VLE bubble/dew point at fixed T."""
function vle(
    kind,
    components,
    t;
    x = nothing,
    y = nothing,
    data = nothing,
    binary = nothing,
    timeout = 120.0,
)
    k = lowercase(String(kind))
    k in ("bubble", "dew") ||
        throw(ArgumentError("vle kind must be 'bubble' or 'dew' (got $(repr(kind)))"))
    comps = _components(components)
    if k == "bubble"
        x === nothing && throw(ArgumentError("bubble vle requires x=[...]"))
        y === nothing || throw(ArgumentError("bubble vle takes x, not y"))
        composition = ["--x", _fractions(x, length(comps), "x")]
    else
        y === nothing && throw(ArgumentError("dew vle requires y=[...]"))
        x === nothing || throw(ArgumentError("dew vle takes y, not x"))
        composition = ["--y", _fractions(y, length(comps), "y")]
    end
    args = _base("vle", binary, data)
    append!(args, ["--kind", k, "--components", join(comps, ","),
                   "--t", _quantity(t, "t"), "--format", "json"])
    append!(args, composition)
    env = _json(args, "vle", timeout)
    return VleResult(
        [String(c) for c in _array(env, "components")],
        String(_required(env, "kind")),
        _required(env, "converged") === true,
        String(_required(env, "status")),
        _as_float(_required(env, "t"), "t"),
        _as_float(_required(env, "p"), "p"),
        Float64[_as_float(v, "x[]") for v in _required(env, "x")],
        Float64[_as_float(v, "y[]") for v in _required(env, "y")],
        _maybe_float(_field(env, "rho_l")),
        _maybe_float(_field(env, "rho_v")),
        env,
    )
end

"""T-x-y envelope for a binary mixture at fixed T."""
function envelope(components, t; points = 21, data = nothing, binary = nothing, timeout = 120.0)
    comps = _components(components)
    n = _points(points)
    args = _base("envelope", binary, data)
    append!(args, ["--components", join(comps, ","), "--t", _quantity(t, "t"),
                   "--points", string(n), "--format", "json"])
    env = _json(args, "envelope", timeout)
    rows = Dict{String,Any}[]
    for row in _array(env, "rows")
        row isa AbstractDict ||
            throw(MmpropsError("protocol: `rows` entry is not an object"; kind = :protocol, raw = env))
        push!(rows, Dict{String,Any}(String(k) => plain(v) for (k, v) in pairs(row)))
    end
    return EnvelopeResult([String(c) for c in _array(env, "components")], rows, env)
end

"""Names of the registered property functions."""
function db_props(; data = nothing, binary = nothing, timeout = 120.0)
    text = _text(_base("db", binary, data), ["props"], "db props", timeout)
    return [String(strip(line)) for line in split(text, '\n') if !isempty(strip(line))]
end

"""Current data-pack identity (`pack_id@pack_version#manifest_sha256`)."""
function db_pack(; data = nothing, binary = nothing, timeout = 120.0)
    return _text(_base("db", binary, data), ["pack"], "db pack", timeout)
end

"""Look up one registered property function."""
function db_show(name; data = nothing, binary = nothing, timeout = 120.0)
    return _text(_base("db", binary, data), ["show", _name(name, "name")], "db show", timeout)
end

# ── internals ──────────────────────────────────────────────────────────────

plain(value::JSON3.Object) =
    Dict{String,Any}(String(k) => plain(v) for (k, v) in pairs(value))
plain(value::JSON3.Array) = Any[plain(v) for v in value]
plain(value) = value

_field(env::Dict{String,Any}, key, default = nothing) = get(env, String(key), default)

function _required(env::Dict{String,Any}, key)
    haskey(env, String(key)) ||
        throw(MmpropsError("protocol: `$(key)` is missing"; kind = :protocol, raw = env))
    return env[String(key)]
end

function _array(env::Dict{String,Any}, key)
    value = _field(env, key)
    value isa AbstractVector ||
        throw(MmpropsError("protocol: `$(key)` is missing or not an array"; kind = :protocol, raw = env))
    return value
end

_as_float(value, what) = value isa Real ? Float64(value) :
    throw(MmpropsError("protocol: $(what) is not a number (got $(repr(value)))"; kind = :protocol))

_maybe_float(value) = value === nothing ? nothing : _as_float(value, "value")

function _name(value, what)
    value isa AbstractString && !isempty(strip(value)) ||
        throw(ArgumentError("$(what) must be a non-empty string (got $(repr(value)))"))
    return String(strip(value))
end

function _quantity(value, what)
    if value isa AbstractString
        isempty(strip(value)) && throw(ArgumentError("$(what) must not be empty"))
        return String(strip(value))
    end
    value isa Bool && throw(ArgumentError("$(what) must be a number or a unit string (got $(repr(value)))"))
    value isa Real ||
        throw(ArgumentError("$(what) must be a number or a unit string (got $(repr(value)))"))
    out = Float64(value)
    isfinite(out) || throw(ArgumentError("$(what) must be finite (got $(repr(value)))"))
    return string(out)
end

function _components(components)
    comps = String[_name(c, "component") for c in components]
    length(comps) == 2 ||
        throw(ArgumentError("binary mixtures need exactly two components (got $(length(comps)))"))
    return comps
end

function _fractions(values, n, what)
    length(values) == n ||
        throw(ArgumentError("$(what) needs $(n) fractions (got $(length(values)))"))
    out = String[]
    for value in values
        value isa Bool && throw(ArgumentError("$(what) entries must be numbers (got $(repr(value)))"))
        value isa Real || throw(ArgumentError("$(what) entries must be numbers (got $(repr(value)))"))
        number = Float64(value)
        (isfinite(number) && 0.0 <= number <= 1.0) ||
            throw(ArgumentError("$(what) entries must be finite and within [0, 1] (got $(repr(value)))"))
        push!(out, string(number))
    end
    return join(out, ",")
end

function _points(value)
    value isa Bool && throw(ArgumentError("points must be an integer >= 1 (got $(repr(value)))"))
    value isa Integer || throw(ArgumentError("points must be an integer >= 1 (got $(repr(value)))"))
    value >= 1 || throw(ArgumentError("points must be an integer >= 1 (got $(repr(value)))"))
    return Int(value)
end

function _base(sub, binary, data)
    args = String[find_binary(binary), sub]
    data === nothing || append!(args, ["--data", String(data)])
    return args
end

function _json(args, op, timeout)
    text = _run(args, op, timeout)
    parsed = try
        JSON3.read(text)
    catch err
        throw(
            MmpropsError(
                "`mmprops $(op) --format json` emitted non-JSON output: $(repr(text)) " *
                "($(sprint(showerror, err)))";
                kind = :protocol,
                op = op,
            ),
        )
    end
    env = plain(parsed)
    env isa Dict{String,Any} ||
        throw(MmpropsError("expected a JSON object from `mmprops $(op)`"; kind = :protocol, op = op))
    return env
end

_text(args, extra, op, timeout) = strip(_run(vcat(args, extra), op, timeout))

function _run(args, op, timeout)
    out_path, out_io = mktemp()
    close(out_io)
    err_path, err_io = mktemp()
    close(err_io)
    try
        proc = run(
            pipeline(ignorestatus(Cmd(args)), stdout = out_path, stderr = err_path);
            wait = false,
        )
        if timeout === nothing
            wait(proc)
        elseif timedwait(() -> Base.process_exited(proc), Float64(timeout)) == :timed_out
            kill(proc, Base.SIGKILL)
            wait(proc)
            throw(MmpropsError("`mmprops $(op)` did not finish within $(timeout)s"; kind = :timeout, op = op))
        end
        err = strip(read(err_path, String))
        if !success(proc)
            message = isempty(err) ? "`mmprops $(op)` exited with code $(proc.exitcode)" : err
            throw(MmpropsError(message; kind = :engine, op = op))
        end
        return read(out_path, String)
    finally
        rm(out_path; force = true)
        rm(err_path; force = true)
    end
end

function _property(env::Dict{String,Any})
    values = Dict{String,Union{Nothing,Float64}}()
    units = Dict{String,String}()
    for row in _array(env, "props")
        row isa AbstractDict ||
            throw(MmpropsError("protocol: `props` entry is not an object"; kind = :protocol, raw = env))
        name = String(row["name"])
        values[name] = _maybe_float(get(row, "value", nothing))
        units[name] = String(get(row, "unit", ""))
    end
    return PropertyResult(String(_field(env, "fluid", "")), values, units, env)
end
