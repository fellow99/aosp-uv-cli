# 002-building-workflow — 模块计划（plan.md，planned → 开发后回写 as-built）

> **模块**：002-building-workflow 构建流水线 · **性质**：技术实现计划（实现落地后回写 as-built 与行号）。
> **依据**：[`../constitution.md`](../constitution.md)（P1–P8）· [`../../docs/000-工程规划.md`](../../docs/000-工程规划.md)（下称「规划 §」）· 本模块 [`spec.md`](./spec.md)（FR-002-xxx）。
> **标记**：✅实测 / ⬜未实测（规划）/ ⚠️风险。**版本**：v1.0 · 2026-11-03 · 状态：⬜ 未实现。

---

## 1. 技术上下文

### 1.1 与姊妹工程的差异（本模块定位）

| 项 | git-cli / python-cli | 本仓（uv） |
|---|---|---|
| provision 门禁扩展 | helper 集 / assets / manifest 一致性 | **无**（单 `.so`、无 assets、无壳脚本，规划 §6） |
| lock 回写 | lock-writeback 工具（python-cli 有先例 `tools/lock-writeback.mjs`） | 同款工具化（本模块核心增量） |
| CI 装机 | make/gcc/perl（C 线） | **rustup + cargo-ndk**（Rust 线，规划 §9） |
| 许可归档 | 四源 tarball（GPLv2）/ LICENSES | uv 双许可（MIT OR Apache-2.0）+ **cargo 依赖许可清单** |

### 1.2 运行环境

- host 工具：Node ≥18（lock 回写工具零第三方依赖，与 provision 同口径）；
- CI：`ubuntu-24.04`（规划 §9 装机清单）；本地等价链路在 Windows Git Bash 验证（001 已保证双环境兼容）。

---

## 2. lock 回写工具设计（`tools/lock-writeback.mjs`，FR-002-001~006）

### 2.1 命令面（沿 000 工具族风格：`--` 参数、退出码 0/2/1）

| 用法 | 行为 | 退出码 |
|---|---|---|
| `--inputs <lock-writeback-inputs.json> --so <libuv_cli.so>` | 门禁自检（`--inspect` 语义）→ 素材与制品复算比对 → 逐字段回写 lock 对应 release | 0 / 2（校验不过）/ 1（用法/IO） |
| `--check`（不落笔） | 干跑：只校验与打印将写入的 diff | 0 / 2 / 1 |
| `--status released` | 明示目标状态（默认 released；draft 只允许 size/sha256 空值时） | — |

### 2.2 回写字段映射（素材 → lock）

```
size        → releases[i].size
sha256      → releases[i].sha256
needed[]    → releases[i].builtFrom.needed（实测 DT_NEEDED 清单，新增字段）
toolchain{} → releases[i].builtFrom.toolchain（结构化：rustVersion/cargoNdk/target/api）
cargoLockSha256 / cargoDeps / tls / ndk / flags → builtFrom 对应字段（规划 §8 扩展）
gates{}     → releases[i].gates（七布尔位按 provision 实测结果）
status      → releases[i].status（draft → released 单向）
active.version / mavenCentral.coordinates → 同步版本；published=false
```

### 2.3 守卫（可证伪）

- released 条目再回写 ⇒ exit 2（FR-002-002）；素材版本 ≠ lock 条目 ⇒ exit 2；
- sha256/size 与目标 `.so` 复算不一致 ⇒ exit 2（FR-002-003）；
- 门禁自检未过（①②③④⑦）⇒ exit 2（FR-002-006）；
- 幂等：同素材二次回写 diff 为空（FR-002-005）。

---

## 3. CI 流水线设计（`.github/workflows/build-uv-cli-android.yml` 重写，FR-002-010~016）

### 3.1 job 结构（替换 scaffold 配置期 CI，保留为前置 job）

```
job config-check（保留 M0：gradle :uv-cli:tasks + 语法门 + 退出码断言修复版自检）
job build-android-arm64（ubuntu-24.04）:
  ① 装机：JDK21(temurin) + Gradle 9.4.1(setup-gradle 钉版) + Node 20
          + NDK 28.2（ANDROID_HOME 布局，或 sdkmanager 钉版）
          + rustup（stable 钉版进 env）+ rustup target add aarch64-linux-android
          + cargo-ndk（cargo install --locked，或 actions/cache 缓存 ~/.cargo/bin）
  ② resolve version：tag v<uvver> ⇒ 版本；否则 PINS 默认（build-only，不发布）
  ③ fetch：node scripts/fetch-uv-cli-source.mjs --uv $VER --out .dist（sha256 门）
  ④ 试编探针（= build 步骤首轮；失败即红，降级决策走 PR 回写规划流程，不在 CI 内自动裁剪）
  ⑤ build：bash scripts/build-uv-cli-android.sh --uv $VER --api 24 --src .dist/src/uv
           --ndk $ANDROID_NDK --out build/out
  ⑥ provision 全门禁（--inspect 断言 exit 0）+ 归档 tar.gz + .sha256 + cargo license 清单
  ⑦ Release（仅 tag）：softprops/action-gh-release 或 gh CLI；归档上载
  ⑧ lock 回写素材产出 + workflow summary 提示（人工回写 PR；M4 再评估自动化）
  缓存：rust-cache 或 actions/cache（~/.cargo + target/，key=rustver+cargolock-sha）
```

### 3.2 退出码断言修复（FR-002-012，000 plan §7 缺陷）

```yaml
- run: |
    code=0; node tools/provision.mjs --check || code=$?
    [ "$code" -eq 2 ] || { echo "unexpected exit $code"; exit 1; }
```

### 3.3 归档清单（FR-002-013）

`libuv_cli.so` + `BUILD-METADATA.txt` + `FETCH-METADATA.json` + `LICENSES/`（uv 双许可 +
依赖许可清单，`cargo license`/`cargo tree` 生成）+ `.sha256`；命名
`uv-cli-v<ver>-android-arm64-v8a.tar.gz`。

---

## 4. FR 交叉引用

| FR | 实现落点（计划） | 现状 |
|---|---|---|
| FR-002-001~006 | `tools/lock-writeback.mjs`（§2） | ⬜ 未实现 |
| FR-002-010~016 | workflow 重写（§3） | ⬜ scaffold CI（配置期） |
| FR-002-012 | 断言修复（§3.2） | ⬜ 缺陷登记于 000 plan §7 |
| FR-002-020/021 | config-check job 保留 + 语法门扩展 | ⬜ 部分（现有 workflow :34-50） |

## 5. 测试考虑（呼应 [test-cases.md](./test-cases.md)）

- L1b（工具纪律）：lock 回写工具的正负例矩阵（守卫逐条可证伪）；
- L2（CI 端到端）：workflow YAML 静态检查（步骤齐全/装机钉版/断言写法/tag 门）在本地以
  `yamllint`/人工清单代行，真实 runner 执行 ⬜ 首轮 tag 后回填。

## 6. 待定项

| # | 事项 | 出口 |
|---|---|---|
| 1 | 缓存策略（rust-cache vs 手动 cache） | 首轮 CI 实测时长后钉（规划 §9 ⬜） |
| 2 | cargo 依赖许可清单生成器（cargo-license 是否入装机） | 首轮归档实测后钉 |
| 3 | lock 回写自动化（CI 直提 PR vs 人工） | M4 评估（规划 §10），本模块只产素材 + summary |
