# 注册到 Julia General（准备清单）

当前状态：**未注册**。Julia General 中 `MMProps` 为空（2026-10-30 检查）；
包 UUID 已定稿为 `b3887540-ec62-4a62-8c6b-d8ae1b2610d9`。

## 前提

- `Project.toml` 的 `version` 与 `[compat]` 已定稿；
- `Pkg.test()` 通过（协议测试；真机集成测试通过 `MMProps.set_binary_path`
  或 `MMPROPS_BIN` 提供二进制）；
- **不要预先打 tag**：tag 由 TagBot 在注册合并后创建
  （`.github/workflows/TagBot.yml` 已配置）。

## 推荐路径：JuliaRegistrator

1. 由 ai4energy 组织管理员把 **JuliaRegistrator** GitHub App 安装到本仓。
2. 在要注册的 commit 上评论：
   ```
   @JuliaRegistrator register
   ```
   如果已有打开的注册 PR，JuliaRegistrator 会把新 commit 追加到该 PR，而不是
   新建一个 —— 请不要修改版本号、包名或仓库 URL。评论中若含其它文字，需要
   加上 `[noblock]` 才不会阻塞 AutoMerge。
3. 合并后 TagBot 自动打 tag；随后即可 `Pkg.add("MMProps")`。

## 备选：手工 PR

在 `ai4energy/General` 的 fork 中添加 `M/MMProps/`：

- `Package.toml`
  ```toml
  name = "MMProps"
  uuid = "b3887540-ec62-4a62-8c6b-d8ae1b2610d9"
  repo = "https://github.com/ai4energy/MMProps.jl.git"
  ```
- `Versions.toml`
  ```toml
  ["0.1.0"]
  git-tree-sha1 = "<git rev-parse v0.1.0^{tree}>"
  ```
- `Deps.toml`（JSON、Preferences）
- `Compat.toml`（`julia = "1.10"`、`JSON = "1"`、`Preferences = "1"`）

然后向 `JuliaRegistries/General` 提 PR。

## 注册前验证

```bash
julia -e 'using Pkg; Pkg.activate(temp=true);
          Pkg.add(url="https://github.com/ai4energy/MMProps.jl");
          using MMProps; println(MMProps.engine_version(MMProps.find_binary()))'
```
