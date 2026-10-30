# 水物性示例：状态点、饱和态、闪蒸。

using MMProps

water = props("water", "300 K", "1 bar")
println("rho = ", water.values["rho"], " ", water.units["rho"])

boiling = sat("water", "373.15 K")
println("psat = ", boiling.values["psat"], " ", boiling.units["psat"])

two_phase = flash("water"; p = "1 bar", h = "1000 kJ/kg")
println("T = ", two_phase.values["t"], " K, x = ", two_phase.values["x"])
