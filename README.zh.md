# MMProps.jl

[![CI](https://github.com/ai4energy/MMProps.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/ai4energy/MMProps.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ai4energy/MMProps.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ai4energy/MMProps.jl)

[English](README.md)

MMPROPS 物性引擎的 **MIT** Julia 客户端。每次调用启动一个 `mmprops` 进程，
读取 JSON 输出；调用之间不保留状态。

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

## 安装

包注册到 General 后：

```julia
using Pkg
Pkg.add("MMProps")
```

注册前可从仓库地址安装：

```julia
Pkg.add(url = "https://github.com/ai4energy/MMProps.jl")
```

还需要 **MMPROPS 引擎二进制**：

- 免费学术版（非商业用途）：
  <https://github.com/ai4energy/mmprops/releases>
- 一次性设置二进制路径：
  ```julia
  MMProps.set_binary_path("/path/to/mmprops")
  ```
  该路径保存为 Julia 包 preference。解析顺序为：显式 `binary=` 参数 →
  `set_binary_path` preference → `MMPROPS_BIN` 环境变量 → `PATH`。环境变量仅
  作为 CI 的兜底方式。
- 显式配置但不可执行的路径会**响亮报错**，客户端不会静默改用其它二进制。

## API

| 调用 | 含义 |
| --- | --- |
| `props(fluid, t, p; data=nothing, binary=nothing, timeout=120.0)` | 状态点物性 → `PropertyResult` |
| `sat(fluid, t; …)` | 饱和态（psat / rho_l / rho_v / hfg）→ `PropertyResult` |
| `flash(fluid; p, h=nothing, s=nothing, …)` | p,h 或 p,s 闪蒸 → `PropertyResult` |
| `vle(kind, components, t; x=nothing, y=nothing, …)` | 二元 VLE 泡/露点 → `VleResult` |
| `envelope(components, t; points=21, …)` | T-x-y 包络 → `EnvelopeResult` |
| `db_props(; …)` / `db_pack(; …)` / `db_show(name; …)` | 注册表与数据包查询 |

`PropertyResult.values` / `.units` 按物性名索引；两相下无定义的量返回 `nothing`。
数值参数可以直接给数（按 SI 解释），也可以给带单位字符串（如 `"300 K"`）。
`vle` / `envelope` 目前只接受**二元**混合物；`x` / `y` 的长度必须与组分数一致。
失败抛 `MmpropsError`，`kind` 区分 `:engine` / `:protocol` / `:timeout` /
`:binary_not_found`；客户端参数错误抛 `ArgumentError`。

## 许可

- **本包**：MIT（见 `LICENSE`）。
- **MMPROPS 引擎**：**商业软件，不是 MIT**（见 `LICENSE-ENGINE.md`）。学术/教学/
  个人非商业用途免费；商业用途需取得商业许可（mingtao.li@gmail.com）。本包不含
  引擎代码，只通过公开 JSON 命令行协议调用引擎。

## 开发

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'                                  # 协议测试（假 CLI）
julia --project=. -e 'using MMProps; MMProps.set_binary_path("/path/to/mmprops")'
julia --project=. test/runtests.jl                                            # 含真机集成
```

协议测试使用 `test/fake_mmprops.jl`；真机集成只在配置了二进制时运行 —— 通过
`MMProps.set_binary_path`，或作为 CI 兜底的 `MMPROPS_BIN` 环境变量。
