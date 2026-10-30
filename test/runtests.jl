using Test
using MMProps

const FAKE = joinpath(@__DIR__, "fake_mmprops.jl")
const ROOT = dirname(@__DIR__)
const SHIM_DIR = mktempdir()

function make_shim()
    shim = joinpath(SHIM_DIR, "mmprops")
    julia = joinpath(Sys.BINDIR, Base.julia_exename())
    open(shim, "w") do io
        println(io, "#!/bin/sh")
        println(io, "exec '$(julia)' --startup-file=no --project='$(ROOT)' '$(FAKE)' \"\$@\"")
    end
    chmod(shim, 0o755)
    return shim
end

const SHIM = make_shim()

function caught(f)
    try
        f()
        return nothing
    catch err
        return err
    end
end

@testset "MMProps.jl" begin
    @testset "props" begin
        out = props("water", "300 K", "1 bar"; binary = SHIM)
        @test out.fluid == "water"
        @test out.values["rho"] ≈ 996.5563375115394
        @test out.units["rho"] == "kg/m3"
        @test out.raw["engine"] == "Water"
        @test engine_version(SHIM) == "0.6.0"
    end

    @testset "sat" begin
        out = sat("water", "373.15 K"; binary = SHIM)
        @test out.values["psat"] ≈ 101417.99636841458
        @test out.values["hfg"] ≈ 2256403.7215263885
    end

    @testset "flash" begin
        out = flash("water"; p = "1 bar", h = "1000 kJ/kg", binary = SHIM)
        @test out.values["t"] ≈ 372.75592898398463
        @test out.values["x"] ≈ 0.2580334879067689
        @test out.values["rho"] === nothing

        out = flash("water"; p = "1 bar", s = "1.1 kJ/(kg·K)", binary = SHIM)
        @test out.values["h"] ≈ 1.0e6

        @test_throws ArgumentError flash("water"; p = "1 bar", binary = SHIM)
        @test_throws ArgumentError flash(
            "water";
            p = "1 bar",
            h = "1 kJ/kg",
            s = "1 kJ/(kg·K)",
            binary = SHIM,
        )
    end

    @testset "vle" begin
        out = vle("bubble", ["methane", "ethane"], "220 K"; x = [0.5, 0.5], binary = SHIM)
        @test out.converged === true
        @test out.kind == "bubble"
        @test out.p ≈ 3993218.987928392
        @test out.y[1] ≈ 0.8479107508105308

        out = vle("dew", ["methane", "ethane"], "220 K"; y = [0.85, 0.15], binary = SHIM)
        @test out.kind == "dew"

        @test_throws ArgumentError vle("bubble", ["methane", "ethane"], "220 K"; binary = SHIM)
        @test_throws ArgumentError vle(
            "bubble",
            ["methane", "ethane"],
            "220 K";
            x = [0.5],
            binary = SHIM,
        )
        @test_throws ArgumentError vle("bubble", ["methane"], "220 K"; x = [1.0], binary = SHIM)
        @test_throws ArgumentError vle(
            "bubble",
            ["methane", "ethane"],
            "220 K";
            x = [0.5, 1.2],
            binary = SHIM,
        )
    end

    @testset "envelope" begin
        out = envelope(["methane", "ethane"], "220 K"; points = 3, binary = SHIM)
        @test length(out.rows) == 3
        @test out.rows[2]["x1"] ≈ 0.5
    end

    @testset "database" begin
        @test "T_sat_water" in db_props(binary = SHIM)
        @test db_pack(binary = SHIM) == "baseline@1#abc123"
        @test occursin("exists", db_show("T_sat_water"; binary = SHIM))
    end

    @testset "client validation" begin
        @test_throws ArgumentError props("water", NaN, "1 bar"; binary = SHIM)
        @test_throws ArgumentError props("water", "300 K", ""; binary = SHIM)
        @test_throws ArgumentError envelope(["methane", "ethane"], "220 K"; points = 0, binary = SHIM)
        @test_throws ArgumentError props(123, "300 K", "1 bar"; binary = SHIM)
        @test props("water", "300 K", "1 bar"; binary = SHIM).values["rho"] > 0
    end

    @testset "engine error" begin
        err = withenv("FAKE_MMPROPS_MODE" => "crash") do
            caught(() -> props("water", "300 K", "1 bar"; binary = SHIM))
        end
        @test err isa MmpropsError
        @test err.kind == :engine
        @test err.op == "props"
        @test occursin("crashed", err.message)
    end

    @testset "protocol error" begin
        err = withenv("FAKE_MMPROPS_MODE" => "bad-json") do
            caught(() -> props("water", "300 K", "1 bar"; binary = SHIM))
        end
        @test err isa MmpropsError
        @test err.kind == :protocol
    end

    @testset "timeout" begin
        err = withenv("FAKE_MMPROPS_MODE" => "silent") do
            caught(() -> props("water", "300 K", "1 bar"; binary = SHIM, timeout = 0.3))
        end
        @test err isa MmpropsError
        @test err.kind == :timeout
    end

    @testset "binary resolution" begin
        missing = joinpath(mktempdir(), "mmprops")
        err = caught(() -> find_binary(missing))
        @test err isa MmpropsError && err.kind == :binary_not_found

        err = withenv("MMPROPS_BIN" => missing) do
            caught(() -> find_binary())
        end
        @test err isa MmpropsError && err.kind == :binary_not_found

        @test find_binary(SHIM) == SHIM
    end

    let bin = get(ENV, "MMPROPS_BIN", nothing)
        if bin === nothing
            @info "MMProps.jl: integration tests skipped — set MMPROPS_BIN to a real `mmprops`"
        else
            @testset "real engine" begin
                water = props("water", "300 K", "1 bar"; binary = bin)
                @test water.values["rho"] ≈ 996.5563375115394 rtol = 1e-6
                @test water.units["rho"] == "kg/m3"

                boiling = sat("water", "373.15 K"; binary = bin)
                @test boiling.values["psat"] ≈ 101417.99636841458 rtol = 1e-6

                two_phase = flash("water"; p = "1 bar", h = "1000 kJ/kg", binary = bin)
                @test two_phase.values["t"] ≈ 372.75592898398463 rtol = 1e-6

                point = vle("bubble", ["methane", "ethane"], "220 K"; x = [0.5, 0.5], binary = bin)
                @test point.converged === true
                @test point.p ≈ 3993218.987928392 rtol = 1e-6
                @test point.y[1] ≈ 0.8479107508105308 rtol = 1e-6

                curve = envelope(["methane", "ethane"], "220 K"; points = 3, binary = bin)
                @test length(curve.rows) >= 3
                @test "T_sat_water" in db_props(binary = bin)
            end
        end
    end
end
