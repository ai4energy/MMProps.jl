# MMProps.jl

[![CI](https://github.com/ai4energy/MMProps.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/ai4energy/MMProps.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ai4energy/MMProps.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ai4energy/MMProps.jl)

[中文说明](README.zh.md)

MMProps.jl is the **MIT-licensed Julia client** for the MMPROPS property
engine. Every call launches a separate `mmprops` process and reads the JSON it
prints; nothing is kept in memory between calls.

```julia
using MMProps

water = props("water", "300 K", "1 bar")
println(water.values["rho"], " ", water.units["rho"])

boiling = sat("water", "373.15 K")
println(boiling.values["psat"])

two_phase = flash("water"; p = "1 bar", h = "1000 kJ/kg")
println(two_phase.values["t"], " ", two_phase.values["x"])

point = vle("bubble", ["methane", "ethane"], "220 K"; x = [0.5, 0.5])
println(point.p, " ", point.y)
```

## Installation

Once the package is registered in the General registry:

```julia
using Pkg
Pkg.add("MMProps")
```

Until then, install it from the repository URL:

```julia
Pkg.add(url = "https://github.com/ai4energy/MMProps.jl")
```

### Engine binary

The client needs the MMPROPS engine binary:

- Academic edition (free for non-commercial use):
  <https://github.com/ai4energy/mmprops/releases>
- Point the client at the binary once:
  ```julia
  MMProps.set_binary_path("/path/to/mmprops")
  ```
  The path is stored as a Julia package preference. The resolution order is
  explicit `binary=` argument → `set_binary_path` preference → `MMPROPS_BIN`
  environment variable → `PATH`. The environment variable exists as a CI
  fallback only.
- A path that is explicitly configured but is not executable raises a loud
  error; the client never silently falls back to another binary.

## API

| Call | Meaning |
| --- | --- |
| `props(fluid, t, p; data=nothing, binary=nothing, timeout=120.0)` | State-point properties → `PropertyResult` |
| `sat(fluid, t; …)` | Saturation state (psat / rho_l / rho_v / hfg) → `PropertyResult` |
| `flash(fluid; p, h=nothing, s=nothing, …)` | p,h or p,s flash → `PropertyResult` |
| `vle(kind, components, t; x=nothing, y=nothing, …)` | Binary VLE bubble/dew point → `VleResult` |
| `envelope(components, t; points=21, …)` | T-x-y envelope → `EnvelopeResult` |
| `db_props(; …)` / `db_pack(; …)` / `db_show(name; …)` | Registry and data-package queries |

`PropertyResult.values` / `.units` are indexed by property name; quantities that
are undefined in a two-phase state come back as `nothing`. Numbers may be given
either as plain values (interpreted in SI) or as unit strings such as
`"300 K"`. `vle` / `envelope` currently accept **binary** mixtures only, and the
length of `x` / `y` must match the number of components. Failures raise
`MmpropsError` with `kind` set to `:engine`, `:protocol`, `:timeout`, or
`:binary_not_found`; invalid client arguments raise `ArgumentError`.

## Development

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'                                  # protocol tests (fake CLI)
julia --project=. -e 'using MMProps; MMProps.set_binary_path("/path/to/mmprops")'
julia --project=. test/runtests.jl                                            # real engine
```

The protocol tests use `test/fake_mmprops.jl`; the real-engine tests run only
when a binary is configured — either through `MMProps.set_binary_path` or, as a
CI fallback, the `MMPROPS_BIN` environment variable.

## License

- **This package**: MIT (see `LICENSE`).
- **MMPROPS engine**: commercial software, **not MIT** (see
  `LICENSE-ENGINE.md`). It is free for academic, teaching, and personal
  non-commercial use; commercial use requires a commercial license
  (mingtao.li@gmail.com). This package contains no engine code and only calls
  the engine through its public JSON command-line protocol.
