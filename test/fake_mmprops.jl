#!/usr/bin/env julia
"""A faithful fake of the `mmprops` CLI for client tests."""

using JSON3

const MODE = get(ENV, "FAKE_MMPROPS_MODE", "ok")

opt(args, name) = begin
    i = findfirst(==(name), args)
    i === nothing ? nothing : (i < length(args) ? args[i + 1] : nothing)
end

emit(obj) = (println(JSON3.write(obj)); 0)

function main(args)
    if "--version" in args
        println("mmprops 0.6.0")
        return 0
    end
    if MODE == "crash"
        println(stderr, "fake mmprops: crashed")
        return 3
    end
    if MODE == "silent"
        while true
            sleep(30)
        end
    end
    if MODE == "bad-json"
        println("this is not json")
        return 0
    end
    isempty(args) && return 2
    sub = args[1]
    if sub == "props"
        opt(args, "--fluid") == "water" || return 2
        opt(args, "--format") == "json" || return 2
        return emit(
            Dict{String,Any}(
                "engine" => "Water",
                "fluid" => "water",
                "props" => [
                    Dict{String,Any}("name" => "rho", "unit" => "kg/m3", "value" => 996.5563375115394),
                    Dict{String,Any}("name" => "h", "unit" => "J/kg", "value" => 112653.67968883849),
                    Dict{String,Any}("name" => "s", "unit" => "J/(kg·K)", "value" => 393.0624338144479),
                ],
                "spec" => Dict{String,Any}("p" => 100000.0, "t" => 300.0),
            ),
        )
    elseif sub == "sat"
        opt(args, "--fluid") == "water" || return 2
        return emit(
            Dict{String,Any}(
                "fluid" => "water",
                "props" => [
                    Dict{String,Any}("name" => "psat", "unit" => "Pa", "value" => 101417.99636841458),
                    Dict{String,Any}("name" => "rho_l", "unit" => "mol/m3", "value" => 53196.49137818544),
                    Dict{String,Any}("name" => "rho_v", "unit" => "mol/m3", "value" => 33.20349107249471),
                    Dict{String,Any}("name" => "hfg", "unit" => "J/kg", "value" => 2256403.7215263885),
                ],
                "spec" => "T=373.15 K",
            ),
        )
    elseif sub == "flash"
        opt(args, "--spec") in ("ph", "ps") || return 2
        (opt(args, "--h") === nothing && opt(args, "--s") === nothing) && return 2
        return emit(
            Dict{String,Any}(
                "fluid" => "water",
                "props" => [
                    Dict{String,Any}("name" => "t", "unit" => "K", "value" => 372.75592898398463),
                    Dict{String,Any}("name" => "x", "unit" => "-", "value" => 0.2580334879067689),
                    Dict{String,Any}("name" => "rho", "unit" => "kg/m3", "value" => nothing),
                    Dict{String,Any}("name" => "h", "unit" => "J/kg", "value" => 1000000.0),
                ],
                "spec" => "p=100000 Pa · phase=two_phase",
            ),
        )
    elseif sub == "vle"
        kind = opt(args, "--kind")
        kind == "bubble" && opt(args, "--x") === nothing && return 2
        kind == "dew" && opt(args, "--y") === nothing && return 2
        comps = split(something(opt(args, "--components"), ""), ",")
        return emit(
            Dict{String,Any}(
                "components" => comps,
                "converged" => true,
                "kind" => kind,
                "p" => 3993218.987928392,
                "rho_l" => 16561.445375954965,
                "rho_v" => 3187.3457116610057,
                "status" => "ok",
                "t" => 220.0,
                "x" => [0.5, 0.5],
                "y" => [0.8479107508105308, 0.15208924918946917],
            ),
        )
    elseif sub == "envelope"
        return emit(
            Dict{String,Any}(
                "components" => split(something(opt(args, "--components"), ""), ","),
                "rows" => [
                    Dict{String,Any}("x1" => 0.001, "y1" => 0.0135, "p" => 499115.0, "status" => "ok", "converged" => true),
                    Dict{String,Any}("x1" => 0.5, "y1" => 0.8479, "p" => 3993218.0, "status" => "ok", "converged" => true),
                    Dict{String,Any}("x1" => 1.0, "y1" => 1.0, "p" => 1000000.0, "status" => "ok", "converged" => true),
                ],
            ),
        )
    elseif sub == "db"
        action = length(args) > 1 ? args[2] : ""
        action == "props" && (println("T_sat_water"); println("T_sat_R134a"); return 0)
        action == "pack" && (println("baseline@1#abc123"); return 0)
        action == "show" && (println("T_sat_water exists arity=1"); return 0)
    end
    println(stderr, "fake: unknown command $(args)")
    return 2
end

exit(main(ARGS))
