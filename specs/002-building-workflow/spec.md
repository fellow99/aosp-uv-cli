# 002 · 构建流水线（building-workflow）功能规格

> 模块：002-building-workflow · 状态：⬜ 规划已立项（规划 §10.2）· 所属工程：aosp-uv-cli
> 规划基线：[`docs/000-工程规划.md`](../../docs/000-工程规划.md) §6（门禁 profile，M1 新增需求=无）/§8（lock 回写）/§9（CI 设计）/§10.1（发布模式）
> 覆盖任务：M1-T5（CI 真实流水线 + Release + lock 回写闭环）

## 1. 目的

把 001 产出的制品**安全地**归档、发布、记账：CI 从配置期门禁升级为真实构建流水线
（rust 装机 → fetch → 试编探针 → 编译 → strip → provision 全门禁 → 归档 → Release）；
lock 回写从「人工改 JSON」升级为**工具化闭环**（draft → released，素材来自 001 的
`lock-writeback-inputs.json`）。本仓单 `.so`、无 assets、无壳脚本 ⇒ **无 provision 门禁扩展**
（规划 §6），门禁面 = CI 接线 + 门禁结果回填。

## 2. 功能需求（FR-002-xxx，RFC 2119；判据可证伪）

### 2.1 lock 回写闭环（工具化，M1-T5 后半）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-002-001 | MUST | 提供 lock 回写工具：读取 001 的 `lock-writeback-inputs.json`，把真实 size/sha256/DT_NEEDED/gates 七布尔位/`builtFrom.toolchain` 结构化字段写进 `uv-cli.lock.json` 对应 release 条目 | 回写后 lock 字段与素材复算一致；JSON 合法（`JSON.parse` 过） |
| FR-002-002 | MUST | status 单向：`draft → released`；已 released 条目禁止被降级回写（P2 唯一事实源） | 对 released 条目再回写 ⇒ 拒绝（exit 2）；版本不匹配 ⇒ exit 2 |
| FR-002-003 | MUST | 回写内容与制品强校验：写入前对目标 `.so` 复算 sha256/size，与素材不一致 ⇒ 拒绝 | 构造素材与产物漂移 ⇒ exit 2，lock 不落笔 |
| FR-002-004 | MUST | `active` 指针与 `mavenCentral.coordinates` 随版本同步更新；`published` 默认 false（P5） | 回写后三者版本一致；published=false |
| FR-002-005 | MUST | 回写幂等：同一素材重复回写结果一致（无重复条目、无字段漂移） | 二次执行 diff 为空 |
| FR-002-006 | MUST | 回写前自检 `provision --check`（已投放制品）或 `--inspect`（归档制品）门禁通过，未过 ⇒ 拒绝落笔 | 门禁失败 ⇒ exit 2，lock 不变 |

### 2.2 CI 真实流水线（M1-T5 前半，规划 §9）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-002-010 | MUST | runner 装机清单钉定：ubuntu-24.04 + JDK 21 + Gradle 9.4.1 + Node 20 + NDK（lock 对齐线）+ **rustup stable + `rustup target add aarch64-linux-android` + cargo-ndk（`cargo install --locked` 或缓存）** + curl/file/tar | workflow 装机步骤逐项可复现（脚本化，无手工 state） |
| FR-002-011 | MUST | 流水线顺序 = 规划 §9：resolve version → fetch（tarball sha256 校验）→ 试编判据（§4.3，首 job 即探针）→ `cargo build --release --locked`（cargo-ndk/config.toml）→ strip → 改名 → provision 全门禁 → 归档 → Release → lock 回写（PR/提示） | 单条 workflow 从 tag/dispatch 产出全部制品；任一步失败即红 |
| FR-002-012 | MUST | **退出码断言语义修复**（000-scaffold plan §7 缺陷登记）：断言写法保证「预期 2」与「意外 1」可区分 | `code=0; node tools/provision.mjs --check \|\| code=$?; [ "$code" -eq 2 ] \|\| exit 1` 口径；负例构造验证 |
| FR-002-013 | MUST | 归档 `uv-cli-v<ver>-android-arm64-v8a.tar.gz` + `.sha256`：`libuv_cli.so` + BUILD/FETCH-METADATA + LICENSES/NOTICES + **cargo 依赖许可清单**（规划 §9） | 归档清单核对逐项在；`.sha256` 复算一致 |
| FR-002-014 | MUST | Release 触发：tag `v<uvver>` push（或 dispatch 输入版本）；tag 与 lock active 版本一致性校验 | tag 版本 ≠ lock ⇒ 流水线失败；成功 Release 含归档与 `.sha256` |
| FR-002-015 | MUST NOT | PR/push（非 tag）**不得**发布 Release，只跑构建 + 门禁（发布卫生 P5） | 非 tag 触发的运行无 Release 产物 |
| FR-002-016 | MUST | 缓存：cargo registry（`~/.cargo`）+ `target/`（key 含 rust 版本 + Cargo.lock sha；Swatinem/rust-cache 或 actions/cache ⬜ 策略实测后钉） | 二次运行命中缓存（日志可证）；缓存 key 漂移即重建 |

### 2.3 配置期门禁保留（M0 能力不回归）

| 编号 | 级别 | 需求 | 可证伪的验收判据 |
|---|---|---|---|
| FR-002-020 | MUST | 无二进制干净工程 `gradle :uv-cli:tasks` 仍必须成功（FR-000-005/040 不回归）；scaffold 配置期 CI 保留为流水线前置 job | 干净检出配置门禁步绿 |
| FR-002-021 | MUST | 语法门（`node --check` ×N + `bash -n`）覆盖全部新增脚本（含 lock 回写工具与 003 harness） | 语法步零告警通过 |

## 3. 边界（不在本模块）

- 源码钉选与交叉编译本身 → **001-building**（CI 只是调用者）；
- 设备上行为验证 → **003-cli**；
- Maven Central 发布（M3，两段式第二段）→ 规划 §10.1 runbook（发布面已由 publish.gradle.kts 内置，非本模块里程碑）。

## 4. 验收场景

- 干净 runner 单条 workflow（tag `v<uvver>` 触发）产出归档 + Release，lock 回写 `released`，
  `provision --check`/`--inspect` 全绿；
- 素材与制品漂移 ⇒ lock 回写工具 exit 2（负例）；
- 非 tag 的普通 push 只构建 + 门禁，不发布；
- 退出码断言：`--check` 未投放=2 视为通过；=1 或其它视为失败（负例构造可区分）。
