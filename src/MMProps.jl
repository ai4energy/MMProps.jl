"""MMProps.jl — MIT Julia client for the MMPROPS property engine.

The engine (`mmprops`) is a commercial binary distributed separately; this
package only runs its public JSON command line and parses the result.
"""

module MMProps

using JSON3

export PropertyResult,
    VleResult,
    EnvelopeResult,
    MmpropsError,
    props,
    sat,
    flash,
    vle,
    envelope,
    db_props,
    db_pack,
    db_show,
    find_binary,
    engine_version

include("errors.jl")
include("binary.jl")
include("cli.jl")

end
