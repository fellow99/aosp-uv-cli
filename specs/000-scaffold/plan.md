# 000-scaffold 技术方案（As-Built）

> 模块：000-scaffold · 需求编号/名称：000-scaffold 工程搭建
> 对应规格：[spec.md](./spec.md) · 任务：[tasks.md](./tasks.md) · 测试：[test-cases.md](./test-cases.md)
> 最后更新：2026-11-02（M0 骨架已完成并通过 scaffold 提交前验证；真实交叉编译属 M1 ⬜）
> 范围：本文件是 000-scaffold 的**实现特定**文档（怎么做）；只写已建成事实 ✅，M1/M2 设计以「规划引用 ⬜」出现并标注规划 § 号（宪法 P6/P8）。
> 规划基线：[`../../docs/000-工程规划.md`](../../docs/000-工程规划.md)（v2.0，下称「规划 §」）；宪法：[`../constitution.md`](../constitution.md)（P1–P8 / S1–S10）。

---

## 1. 技术上下文

### 1.1 运行环境（as-built ✅）

| 项 | 值 | 落点 |
|---|---|---|
| Gradle | 9.4.1（CI `gradle/actions/setup-gradle@v4` 钉版；本地执行记录同版 + Temurin 21） | `.github/workflows/build-uv-cli-android.yml:29-32`；仓库**无 Wrapper**（外部提供） |
| AGP | 9.2.1（版本目录唯一条目） | `gradle/libs.versions.toml:2,5` |
| 发布插件 | `com.vanniktech.maven.publish.base` **0.37.0**（settings pluginManagement 加载） | `settings.gradle.kts:3` |
| 模块 | 仅 `:uv-cli`；rootProject.name=`aosp-uv-cli`；`FAIL_ON_PROJECT_REPOS` | `settings.gradle.kts:13,20-21` |
| SDK / ABI | compileSdk 36 / minSdk 24 / `abiFilters += "arm64-v8a"` / namespace `org.fellow99.uvcli` | `uv-cli/build.gradle.kts:29-35` |
| 打包语义 | `useLegacyPackaging = true`（exec 型硬要求，D1） | `uv-cli/build.gradle.kts:37-44` |
| 版本源 | `CLI_VERSION`（缺失即 `error()`）+ `afterEvaluate` 反射覆写 publication version | `uv-cli/build.gradle.kts:16-26` |
| 发布门禁 | `RELEASE=false` 默认；Token 缺失时 Central/签名任务 `enabled=false` | `gradle.properties:19` · `publish.gradle.kts:71-73,133-139` |
| host 工具 | Node（ESM）；provision/fetch 零第三方依赖 | `tools/provision.mjs` / `scripts/fetch-uv-cli-source.mjs` |
| CI runner | `ubuntu-24.04` + JDK 21（temurin）+ Gradle 9.4.1；job `config-check`，timeout 20 min | workflow `:17-32` |

### 1.2 依赖

- **Gradle 侧**：`com.android.library`（AAR 容器）+ `com.vanniktech.maven.publish.base`（发布面，默认禁用）。无其它依赖。
- **host 工具侧**：仅 Node 内置模块（`node:fs` / `node:path` / `node:crypto` / `node:url`）。
- **上游构建输入（⬜ M1，非 Gradle 依赖）**：uv 官方源码 tarball（含 `Cargo.lock`）、rustup stable + `aarch64-linux-android` target、cargo-ndk、NDK（对齐 aosp-node-runtime 线）。
- **运行期（⬜ 规划引用）**：`libc++_shared.so` 由消费方包内 node-runtime 供给（D5）；python 解释器由 aosp-python-cli 供给（D7）；git 由 aosp-git-cli 供给。

---

## 2. 与宪法的合规（逐条，详细论证见 [../overall-plan.md](../overall-plan.md) §2）

| 原则 | 判定 | 本模块落点 |
|---|---|---|
| P1 fetch 不改源 | ✅ 纪律层 | fetch 骨架只固化接口；M1 行为限定「下载+校验+解压」 |
| P2 lock 唯一事实源 | ✅ | `uv-cli.lock.json` draft（size=0/sha256=""，不伪造）；坐标版本唯一取 `CLI_VERSION` |
| P3 二进制不入库 | ✅ | `.gitignore:23,26-28`；TC-05 已验 |
| P4 门禁强制 | ✅ | 七门禁 + 兄弟文件检查 + BANNED_IN_AAR；`--out` 不过即拒（exit 2） |
| P5 发布卫生 | ✅ | `RELEASE=false` + 凭据仅用户级（模板文件单独提供） |
| P6 未实测 ⬜ | ✅ | 本文件所有 M1/M2 结论均 ⬜ 规划引用 |
| P7 不下载上游二进制 | ✅ 纪律层 | 规划 D3/D7；本模块无任何下载行为（骨架 exit 2） |
| P8 先改文档再改实现 | ✅ | 规划 v2.0 先行；本 specs 体系随后（本文件为其一） |

---

## 3. 数据模型（`uv-cli.lock.json`）

### 3.1 根结构（as-built，53 行 ✅）

```jsonc
{
  "$comment":  "唯一事实源说明（draft 语义 + 指向规划）",
  "active":    { "version": "0.9.0", "abi": "arm64-v8a" },          // 默认选定 release（provision 未传参时）
  "releases":  [ ReleaseRecord ],                                    // 当前恰 1 条（draft）
  "matrix": {
    "minSdk": 24,
    "abi": ["arm64-v8a"],
    "allowedNeeded": ["libc.so","libm.so","libdl.so","libz.so","liblog.so","libc++_shared.so"],
    "execPackaging": "useLegacyPackaging=true … SELinux 禁止从 app 数据目录 exec",
    "note": "… libc++_shared.so 由消费方 node-runtime 供给（不随包）"
  }
}
```

### 3.2 `ReleaseRecord`（当前唯一条目，draft 真实值）

```jsonc
{
  "version": "0.9.0",            // draft 计划版本；首产按 CI 实际钉选的 uv 版本回写（规划 §2）
  "abi": "arm64-v8a",
  "androidApi": 24,
  "name": "libuv_cli.so",        // DEFAULT_BINARY（D6）
  "size": 0,                     // FR-000-013：draft 占位，不伪造
  "sha256": "",                  // 同上（空串）
  "builtFrom": {
    "source":   "uv <ver> source tarball (github.com/astral-sh/uv releases), unmodified; Rust cross-compile",
    "toolchain":"rust aarch64-linux-android target (tier2) + cargo-ndk; TLS via rustls with bundled roots",  // prose（⚠️ 待结构化，见 3.3）
    "ndk":      "TBD (first CI build pins NDK line + version)",
    "flags":    "TBD: -C link-arg=-Wl,-z,max-page-size=16384; strip"
  },
  "gates": {                     // 七门禁布尔位（FR-000-012），与 provision 门禁一一对应
    "eTypeEtDyn": true, "ptInterpSystemLinker": true, "eMachineAArch64": true,
    "neededWhitelist": true, "sha256Match": true, "sizeMatch": true, "pageAlign16k": true
  },
  "mavenCentral": { "coordinates": "io.github.fellow99:uv-cli:0.9.0", "published": false },
  "status": "draft"              // draft → released（首个真实 CI 构建后人工回写）
}
```

### 3.3 `builtFrom.toolchain` 结构化扩展设计（⬜ 规划引用，规划 §8「lock 扩展字段设计 v2.0」）

> 现 draft 的 `toolchain` 是**单句 prose**、`flags`/`ndk` 为 **TBD**——这是 draft 语义下的如实占位（FR-000-013），不是缺陷。M1 回写时按以下结构落地（**规划原文引用，未实现**）：

```jsonc
"builtFrom": {
  "source": "uv <ver> source tarball (github.com/astral-sh/uv releases), unmodified",
  "toolchain": {                        // 结构化扩展（M1 落地）
    "rustVersion": "<rustup stable 钉版>",
    "cargoNdk": "<cargo-ndk 版本>",
    "target": "aarch64-linux-android",
    "api": 24
  },
  "cargoLockSha256": "<tarball 内 Cargo.lock 整文件 sha256>",
  "cargoDeps": [ { "name": "ring", "version": "…", "sha256": "…" } ],  // 粒度 ⬜ 见下
  "tls": "rustls + bundled roots（provider/根证书来源以实测为准 ⬜）",
  "ndk": "…", "flags": "-C link-arg=-Wl,-z,max-page-size=16384; strip"
}
```

- **依赖 sha 记录粒度（⬜ M1 拍板，规划 §8 两方案）**：方案 A = `Cargo.lock` 整文件 sha256 + `cargo license` 清单随 Release 归档（轻）；方案 B = 逐 crate `.crate` 文件 sha256 全量记录（重，供应链审计口径）。**规划倾向 A + cc 类 C 依赖（ring/zstd-sys 等）逐条记录**；拍板后先回写规划再回填 lock（P8）。
- **DT_NEEDED 实测清单回填**：首产以 provision/readelf 输出为准回填（规划 §6 M1 新增需求行）。

---

## 4. provision CLI 与退出码契约（as-built ✅，`tools/provision.mjs` 276 行）

### 4.1 命令面（FR-000-030）

| 用法 | 行为 | 退出码 |
|---|---|---|
| `--check` | 校验已投放产物：`<MODULE_JNILIBS>/<abi>/<name>`；缺失 ⇒ 打印「未投放」并 **exit 2**（S1 语义）；存在则跑七门禁 + **兄弟文件检查**（目录内仅 `libuv_cli.so`） | 0 / 2 |
| `--inspect <so>` | 打印某产物的门禁报告，**不写任何文件** | 0 / 2（非 ELF 解析失败同为 2）/ 1（文件读取等 IO 错误） |
| `--out <dir> --from <so>` | 过门禁后投放单个 `.so` 到 `<dir>/<abi>/`，写 `META-INF/uv-cli.properties`，随后校验 `BANNED_IN_AAR` | 0 / 2 / 1 |
| `--version <v> --abi <a>` | 选择 lock 中 release（默认 `active`）；未命中 ⇒ 抛错 exit 1 并列出现有条目 | — / 1 |
| `--allow-page-align-4k` | 仅放行门禁 ⑦ 并打印「仅 bring-up」警告（`provision.mjs:162-167`） | — |
| 顶层异常（缺文件/JSON 解析失败等） | stderr 打印 `[provision] 失败：…` | 1（`:271-276`） |

### 4.2 七门禁（FR-000-032/033；行号 = 2026-11-02 快照）

| # | 判据 | 落点 | draft 行为 |
|---|---|---|---|
| ① | `e_type == 3`（ET_DYN，PIE） | `gates()` :146 | 照判 |
| ② | `PT_INTERP == 1` 且内容 `== '/system/bin/linker64'`（`parseElf` :76-90 提取内容） | :148-150 | 照判（**exec 型与 pty 相反**） |
| ③ | `e_machine == 183`（AArch64） | :151 | 照判 |
| ④ | DT_NEEDED ⊆ `lock.matrix.allowedNeeded`（白名单制，越界列出具体库名） | :153-155 | 照判 |
| ⑤ | SHA-256 == lock（64 位十六进制才算有锁值） | :141,156-157 | 无锁值 ⇒ **仅记录** |
| ⑥ | size == lock（>0 才算有锁值） | :142,158-159 | 无锁值 ⇒ **仅记录** |
| ⑦ | min LOAD align ≥ 0x4000（16KB） | :140,160 | 照判（`--allow-page-align-4k` 可放行此位，仅 bring-up） |
| 附 | 兄弟文件检查（`--check` 路径）：目录内其它 `.so` 即不合格 | :222-225 | — |
| 附 | 投放后 `BANNED_IN_AAR=['libnode.so']` 存在性校验（命中即抛错 exit 1） | :38,246-250 | — |

### 4.3 投放与元数据（FR-000-034/036）

- 只复制本工具二进制（`:240-245`，`✔ 投放（唯一原生件）`）。
- 写 `uv-cli/src/main/resources/META-INF/uv-cli.properties`：`tool.version` / `abi` / `name` / `size` / `sha256` /（`paired.runtime` 仅当 lock 有 `pairedRuntime`——本仓无配对，故不出现）/ `provisionedAt`（ISO 时间）（`:252-267`）。

### 4.4 lock 读取契约

- `readLock()`（:177-180）：缺文件或 JSON 非法 ⇒ 抛错 exit 1。
- `allowedNeeded` 兜底：`lock.matrix.allowedNeeded ?? ['libc.so','libm.so','libdl.so','libz.so']`（:184）——兜底集合**不含** `libc++_shared.so`，即 lock 缺 matrix 时产物不得依赖 libc++_shared（防误放行）。
- draft 提示：`status==='draft'` 时打印「sha/size 无锁值，仅记录不比对」（:197）。

---

## 5. 文件清单（真实行数，2026-11-02 快照；FR 交叉引用对齐 [spec.md](./spec.md)）

| 文件 | 行数 | 用途 | 对应 FR / 条款 |
|---|---|---|---|
| `settings.gradle.kts` | 21 | root 名 + 仅 include `:uv-cli` + vanniktech 0.37.0 注册 + 仓库模式 | FR-000-001 |
| `gradle.properties` | 19 | GROUP / CLI_VERSION=0.9.0 draft / POM_* / RELEASE=false | FR-000-003 · P5（⚠️ `VERSION_NAME=0.1.0` 为未生效遗留元数据，见 STRUCTURE §2.2） |
| `gradle/libs.versions.toml` | 5 | AGP 9.2.1 版本目录 | FR-000-002（插件面） |
| `publish.gradle.kts` | 139 | vanniktech 发布面：coordinates/pomFromGradleProperties/Central+签名/单 variant/SCM 补丁/RELEASE 门禁 | P5 · 发布面（Maven 动作 ⬜ M3） |
| `gradle.properties.local.example` | 8 | 用户级凭据模板（不入库） | P5 |
| `uv-cli/build.gradle.kts` | 45 | AAR 容器 + 版本接线（CLI_VERSION + 反射覆写）+ abiFilters + `useLegacyPackaging=true` | FR-000-002/003/004/005 |
| `uv-cli.lock.json` | 53 | 唯一事实源（draft + allowedNeeded + execPackaging 语义） | FR-000-010~013 |
| `tools/provision.mjs` | 276 | 投放 + exec 七门禁 + 兄弟文件检查 + BANNED + 元数据 | FR-000-030~036 |
| `scripts/fetch-uv-cli-source.mjs` | 53 | 取源骨架（`--uv/--out`；exit 2 SCAFFOLD） | M1-T2 接口 ⬜（规划 §10） |
| `scripts/build-uv-cli-android.sh` | 58 | 交叉编译骨架（`--uv/--api/--src/--ndk/--out`；七条纪律注释；exit 2 SCAFFOLD） | M1-T3/T4 接口 ⬜（规划 §4.2/§10） |
| `.github/workflows/build-uv-cli-android.yml` | 50 | CI（scaffold）：配置期门禁 + provision 退出码自检（断言 =2）+ 语法门 | FR-000-040~042 |
| `.gitignore` | 31 | jniLibs `.so` / `.dist/` / `build/out/` / `target/` / 构建产物 / keystore | P3（TC-05） |
| `uv-cli/THIRD-PARTY-NOTICES.md` | 16 | uv 双许可 + 工具链许可 + cargo license 清单随 Release 归档纪律 | 许可条款 |
| `README.md` / `README_zh.md` | 73 / 69 | 定位/版本口径/构建要点/exec 打包要点/锁定与校验/退出码 | 文档条款 |
| `LICENSE` | 21 | MIT（本仓自身代码） | — |
| `docs/000-工程规划.md` | 343 | 唯一规划基线（v2.0，含 D1–D7 与 M1/M2 设计） | P8 |
| `specs/`（本目录） | 10 文件 | 规格体系（spec/plan/tasks/test-cases + 项目级 7 件） | P8 |

---

## 6. FR 交叉引用（spec.md ↔ 本方案 ↔ 现状）

| FR（spec.md §2 摘要口径） | 实现落点 | 现状 |
|---|---|---|
| FR-000-001 root 名 + 单模块 | `settings.gradle.kts:20-21` | ✅ |
| FR-000-002 Android library / namespace / SDK / ABI | `uv-cli/build.gradle.kts:29-35` | ✅ |
| FR-000-003 坐标 + CLI_VERSION 独立 semver | `gradle.properties:4-7` + `build.gradle.kts:16-26` + `publish.gradle.kts:36-39` + lock | ✅（版本值 draft） |
| FR-000-004 useLegacyPackaging=true | `uv-cli/build.gradle.kts:37-44` + lock `matrix.execPackaging` | ✅ |
| FR-000-005 无 `.so` 配置期成功 | TC-01/02 已验；CI `:34-35` | ✅ |
| FR-000-010~013 lock 纪律（draft 不伪造哈希；allowedNeeded 含 `libc++_shared.so`） | `uv-cli.lock.json`（§3.1/3.2） | ✅（draft 态；released 回写 ⬜ M1） |
| FR-000-030~036 provision（退出码 0/2/1；仅投放 `libuv_cli.so`；jniLibs 禁入 `libnode.so`） | `tools/provision.mjs`（§4.1–4.4） | ✅（真实产物过门禁 ⬜ M1） |
| FR-000-040~042 CI 配置期门禁（`gradle :uv-cli:tasks`；provision `--check` 未投放=2；语法门） | workflow `:34-50` | ✅ |
| （M1 规划引用，未设 FR 号）fetch/build 完整实现、CI 真实流水线、Release、lock 回写 | 规划 §4.2/§4.3/§9/§10 M1-T1–T5 | ⬜ |

---

## 7. 测试考虑（呼应 [test-cases.md](./test-cases.md)）

- TC-01/02（配置期 + AAR 产出）、TC-03（未投放 exit 2）、TC-04（语法门）、TC-05（二进制不入库）已于 **2026-11-02 全过**（执行记录见 test-cases.md）。
- provision 的门禁位负例矩阵（非 ELF / 非 PIE / 非 linker64 interp / 非 AArch64 / 越白名单 / 4K 对齐 / 哈希不符 / 兄弟文件混入）在 M1 首产时用真实/构造产物补齐（见 [../overall-test-cases.md](../overall-test-cases.md) §2.2 TC-M1-03~09）⬜。
- CI 的退出码断言把「未投放=2」固化为回归线：任何改动若令未投放语义漂移，CI 即红（workflow `:37-45`）。
  - ⚠️ 缺陷登记（2026-11-02 评审）：GHA 默认 `bash -e` 下 exit 2 即终止 step，`code=$?` 与「其它非零」分支不可达——「CI 即红」成立，但无法区分预期 2 与意外 1；M1-T5 改为 `code=0; node tools/provision.mjs --check || code=$?; [ "$code" -eq 2 ] || exit 1`。

---

## 8. 待实现清单 + 验收判据（⬜ 规划引用）

| # | 事项 | 出口判据（可证伪） | 规划锚点 |
|---|---|---|---|
| 1 | M1-T1 C 依赖试编（ring/zstd-sys/…） | `cargo build --target --locked` 过 + 产物过全门禁；失败 ⇒ 降级方案先回写规划 | §4.3 / R1/R2 |
| 2 | M1-T2 fetch 完整实现 | 同版本两次 fetch 结果一致；tarball SHA-256 校验生效 | §10 M1-T2 |
| 3 | M1-T3 rust 工具链装配 + 16KB RUSTFLAGS + cc 环境 | 首轮 `cargo build --target --locked` 通过 | §4.1/§10 M1-T3 |
| 4 | M1-T4 strip + 改名 + 全门禁 | 门禁全过；DT_NEEDED 实测清单回填 lock | §10 M1-T4 |
| 5 | M1-T5 CI 真实流水线 + Release + lock 回写 | G1（编译过门禁并 Release）/ G2（归档完整过校验）/ G4（lock=released） | §9/§10/§10.1 |
| 6 | M2 消费方注入 + 真机探针 P1–P6 | G3（回程成功） | §7/§7.1 |
| 7 | M3 Maven Central | 制品可拉取且坐标正确；`mavenCentral.published=true` | §10.1 / runbook |
| 8 | lock `builtFrom.toolchain` 结构化 + 依赖 sha 粒度拍板 | 结构化字段落地；粒度方案回写规划后按新粒度回填 | §8 |
| 9 | ⚠️ 清理 `VERSION_NAME=0.1.0`（未生效遗留元数据） | 属性删除或注释，文档同步 | 观察（STRUCTURE §2.2-1） |
