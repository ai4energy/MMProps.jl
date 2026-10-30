"""Locate the MMPROPS **engine binary** and read its version."""

const _VERSION_RE = r"\bmmprops\s+(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\b"

"""
    find_binary(explicit=nothing) -> String

Resolution order: `explicit` → `ENV["MMPROPS_BIN"]` → `PATH`. An explicitly
given path that is not executable is a loud error.
"""
function find_binary(explicit = nothing)
    for (source, candidate) in
        (("argument", explicit), ("MMPROPS_BIN", get(ENV, "MMPROPS_BIN", nothing)))
        candidate === nothing && continue
        path = expanduser(String(candidate))
        if isfile(path) && Sys.isexecutable(path)
            return path
        end
        throw(
            MmpropsError(
                "the MMPROPS engine binary from $(source) is not an executable file: $(repr(path))";
                kind = :binary_not_found,
            ),
        )
    end
    found = Sys.which("mmprops")
    found === nothing || return String(found)
    throw(
        MmpropsError(
            "the MMPROPS engine binary (`mmprops`) was not found: put it on PATH or set " *
            "MMPROPS_BIN=<path>. The academic binary is published at " *
            "https://github.com/ai4energy/mmprops/releases.";
            kind = :binary_not_found,
        ),
    )
end

"""Return the engine version string (e.g. `"0.6.0"`), or `nothing`."""
function engine_version(binary::AbstractString)
    out = try
        read(ignorestatus(Cmd([String(binary), "--version"])))
    catch
        return nothing
    end
    m = match(_VERSION_RE, String(out))
    return m === nothing ? nothing : String(m.captures[1])
end
