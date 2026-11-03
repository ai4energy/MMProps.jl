"""Locate the MMPROPS **engine binary** and read its version."""

const _VERSION_RE = r"\bmmprops\s+(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\b"
const _BINARY_PREFERENCE = "binary_path"

"""
    set_binary_path(path) -> String

Persist the path to the MMPROPS engine binary as a Julia package preference.
The preference is read by [`find_binary`](@ref) before `MMPROPS_BIN` and
`PATH`, so client code does not need an environment variable.

The path must already be an executable file; this function does not download
or install the engine.
"""
function set_binary_path(path::AbstractString)
    expanded = abspath(expanduser(String(path)))
    if !(isfile(expanded) && Sys.isexecutable(expanded))
        throw(
            ArgumentError(
                "the MMPROPS engine binary is not an executable file: $(repr(expanded))",
            ),
        )
    end
    Preferences.set_preferences!("MMProps", _BINARY_PREFERENCE => expanded)
    return expanded
end

"""
    find_binary(explicit=nothing) -> String

Return the path to the `mmprops` executable.

Resolution order: `explicit` argument → `set_binary_path` preference →
`ENV["MMPROPS_BIN"]` → `PATH`. A path that was given explicitly, by
preference, or via `MMPROPS_BIN` but is not an executable file is a loud
error — the client never silently falls back to another binary.
"""
function find_binary(explicit = nothing)
    preference = @load_preference("binary_path", nothing)
    for (source, candidate) in (
        ("argument", explicit),
        ("MMProps.set_binary_path", preference),
        ("MMPROPS_BIN", get(ENV, "MMPROPS_BIN", nothing)),
    )
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
            "the MMPROPS engine binary (`mmprops`) was not found: call " *
            "`MMProps.set_binary_path(\"/path/to/mmprops\")`, set `MMPROPS_BIN`, or " *
            "put it on `PATH`. The academic binary is published at " *
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
