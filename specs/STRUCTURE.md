# STRUCTURE.md —— `aosp-uv-cli` 目录与文件结构（as-built）

> **性质**：项目级结构规格（现状快照 + 规划落点）。本文件只描述「文件在哪、干什么、进不进 git/包」。
> **依据**：`specs/constitution.md`（原则 P1–P8）· [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（唯一规划基线，v2.0，下称「规划 §」）· 本仓库工作区实际文件清单 ✅实测。
> **版本**：v1.0 · 2026-11-02 · 状态：**M0 骨架已完成**（规划 §10）；M1 真实交叉编译未开工（文中一律 ⬜ 规划引用）。
> **标记**：✅实测（本仓库可复核）/ ⬜规划引用（不得当作既成事实）/ ⚠️事实性观察。
>
> **一句话边界**：`uv-cli/` 是**唯一产品**（AAR 容器，内含且仅含 `jni/arm64-v8a/libuv_cli.so`）；`tools/` `scripts/` `specs/` `docs/` `.github/` 是**配套物**，彼此不反向依赖。

---

## 1. 顶层目录树（逐文件一行用途，行数为 2026-11-02 快照 ✅实测）

```
aosp-uv-cli/                            # node-bridge-workspace 的 submodule；本仓不含 Gradle Wrapper ⚠️
├── README.md                           # 73 行 · 英文总览：定位/版本跟随 uv/构建口径/exec 打包要点/锁定与校验
├── README_zh.md                        # 69 行 · 中文总览（与英文同构）
├── LICENSE                             # 21 行 · MIT（本仓自身代码）；uv 本体为 MIT OR Apache-2.0 双许可（另计）
├── settings.gradle.kts                 # 21 行 · rootProject.name=aosp-uv-cli（:20）+ include(":uv-cli")（:21）
│                                       #   + pluginManagement 注册 vanniktech 0.37.0（:3）+ FAIL_ON_PROJECT_REPOS（:13）
├── gradle.properties                   # 19 行 · GROUP（:2）/ VERSION_NAME=0.1.0（:3，⚠️非坐标版本源，见 §2.2）
│                                       #   / CLI_VERSION=0.9.0 draft（:7）/ POM_*（:8-16）/ RELEASE=false（:19）
├── gradle.properties.local.example     # 8 行  · 用户级凭据模板（Central Portal Token / GPG；真值文件不提交）
├── gradle/
│   └── libs.versions.toml              # 5 行  · AGP 9.2.1 版本目录（:2）+ android-library 插件别名（:5）
├── publish.gradle.kts                  # 139 行 · vanniktech 发布面共享配置（由 :uv-cli apply）：
│                                       #   coordinates(io.github.fellow99, uv-cli, CLI_VERSION)（:36-39）
│                                       #   publishToMavenCentral(false, NONE|PUBLISHED)（:45-56）+ 签名（:75-113）
│                                       #   + POM SCM url 补丁（:116-131）+ RELEASE=false 门禁（:133-139）
├── uv-cli.lock.json                    # 53 行 · ★ 唯一事实源（active + releases[draft] + matrix.allowedNeeded）
├── uv-cli/                             # ★★ 唯一发布物：io.github.fellow99:uv-cli:<CLI_VERSION>（AAR 容器）
│   ├── build.gradle.kts                # 45 行 · com.android.library + vanniktech base；版本唯一取 CLI_VERSION（:16-17）
│   │                                   #   + publication 反射覆写（:19-26）；namespace org.fellow99.uvcli（:29）
│   │                                   #   compileSdk 36 / minSdk 24 / abiFilters [arm64-v8a]（:29-35）
│   │                                   #   useLegacyPackaging=true（:42，exec 型硬要求）
│   ├── THIRD-PARTY-NOTICES.md          # 16 行 · uv 双许可 + Rust 工具链许可 + cargo 依赖清单随 Release 归档的纪律
│   └── src/main/                       # 无任何 Kotlin/Java 源——模块只是 AAR 容器（build.gradle.kts:11 注释）
│       └── jniLibs/arm64-v8a/          # ⬜ 投放落点（当前不存在/为空；provision --out 写入；.so 不入库）
├── tools/
│   └── provision.mjs                   # 276 行 · ✅ 投放 + exec 型七门禁 + jniLibs 兄弟文件检查 + BANNED_IN_AAR
│                                       #   + META-INF/uv-cli.properties 版本元数据；退出码 0/2/1
├── scripts/
│   ├── fetch-uv-cli-source.mjs         # 53 行 · 骨架（exit 2 SCAFFOLD）：固化 --uv/--out 接口；下载/校验 ⬜ M1
│   └── build-uv-cli-android.sh         # 58 行 · 骨架（exit 2 SCAFFOLD）：固化 --uv/--api/--src/--ndk/--out
│                                       #   + rust/cargo-ndk 七条纪律注释（:5-13）；真实编译链 ⬜ M1
├── .github/workflows/
│   └── build-uv-cli-android.yml        # 50 行 · CI（scaffold）：配置期门禁（:34-35）+ provision 退出码自检（:37-45）
│                                       #   + 脚本语法门（:47-50）；真实流水线 ⬜ M1 并入替换
├── docs/
│   └── 000-工程规划.md                  # 343 行 · ★ 唯一规划基线（v2.0：M0 已完成 + M1/M2 实现设计 + D1–D7 决策）
├── specs/                              # 规格体系（本目录；见 SPECS_CHECKLIST.md）
│   ├── README.md                       # 规格索引（最后生成）
│   ├── constitution.md                 # 项目宪法（原则 P1–P8 + 证据纪律 + 评审清单）
│   ├── STRUCTURE.md / TECH.md / ARCHITECTURE.md        # 项目级三件
│   ├── overall-spec.md / overall-plan.md / overall-test-cases.md   # 整体规格三件
│   ├── SPECS_CHECKLIST.md              # 完成度追踪
│   └── 000-scaffold/                   # 模块规格：spec.md / plan.md / tasks.md / test-cases.md
└── .gitignore                          # 31 行 · jniLibs/**/*.so（:23）+ .dist/ build/out/ target/（:26-28）+ 构建/密钥
```

---

## 2. 关键配置文件位置（现状 ✅实测）

| 文件 | 关键内容（as-built） | 规划锚点 |
|---|---|---|
| `settings.gradle.kts` | root 名 `aosp-uv-cli`；仅 include `:uv-cli`；vanniktech `com.vanniktech.maven.publish.base` **0.37.0** 经 pluginManagement 加载；`RepositoriesMode.FAIL_ON_PROJECT_REPOS` | 规划 §10 M0 |
| `gradle.properties` | `GROUP=io.github.fellow99`；`CLI_VERSION=0.9.0`（draft 计划版本，首产后按 lock 回写）；`RELEASE=false`（发布门禁默认关）；`POM_LICENCE_NAME=MIT License` | 规划 §2 / §10.1 |
| `gradle/libs.versions.toml` | `agp = "9.2.1"`（唯一版本目录条目） | — |
| `uv-cli/build.gradle.kts` | `useLegacyPackaging = true`（D1）；坐标版本唯一源 `CLI_VERSION`（缺失即 `error()`）；`abiFilters += "arm64-v8a"`；`namespace = "org.fellow99.uvcli"` | 规划 §3.1 D1/D2/D6 |
| `publish.gradle.kts` | `coordinates("io.github.fellow99", "uv-cli", <CLI_VERSION>)`；`publishToMavenCentral(requiresToken=false, validation=NONE)`（`-PAUTOMATIC_RELEASE=true` 时 PUBLISHED）；`signAllPublications`；`AndroidSingleVariantLibrary(release + sources jar)`；RELEASE=false 或缺 Token ⇒ Central/签名任务全部禁用 | 规划 §10.1（Maven 随后，M3） |
| `uv-cli.lock.json` | `active={version:0.9.0, abi:arm64-v8a}`；唯一 release `status="draft"`（`size:0`、`sha256:""`，不伪造哈希）；`matrix.allowedNeeded=[libc.so, libm.so, libdl.so, libz.so, liblog.so, libc++_shared.so]` | 规划 §8 |
| `.gitignore` | `uv-cli/src/main/jniLibs/**/*.so`、`.dist/`、`build/out/`、`target/`（Rust 构建目录）、keystore/密钥 | 宪法 P3 |

### 2.1 `.github/workflows/build-uv-cli-android.yml`（scaffold CI）

| 步骤 | 内容 | 状态 |
|---|---|---|
| 触发 | `push: branches [main]` + `pull_request` + `workflow_dispatch`；`permissions: contents: read` | ✅ |
| 环境 | `ubuntu-24.04` + JDK 21（temurin）+ Gradle 9.4.1（`gradle/actions/setup-gradle@v4`） | ✅ |
| 配置期门禁 | `gradle :uv-cli:tasks --console=plain`（无 `.so` 必须通过） | ✅ |
| provision 自检 | `node --check tools/provision.mjs`；`provision --check` **断言退出码 == 2**（未投放语义，其它非零视为工具缺陷） | ✅ |
| 语法门 | `node --check scripts/fetch-uv-cli-source.mjs` + `bash -n scripts/build-uv-cli-android.sh` | ✅ |
| 真实流水线（fetch→cargo→strip→门禁→Release） | ⬜ 规划 §9（M1 并入本文件替换 scaffold job 保留为前置） | ⬜ |

### 2.2 ⚠️ 两处事实性观察（评审必读）

1. **`VERSION_NAME=0.1.0` 不是坐标版本源**：`gradle.properties:3` 存在该属性，但 `publish.gradle.kts:36-39` 的 `coordinates(...)` 与 `uv-cli/build.gradle.kts:16-17` 的 `project.version` **都只取 `CLI_VERSION`**；`pomFromGradleProperties`（`publish.gradle.kts:40`）消费的是 `POM_*` 键。⇒ `VERSION_NAME` 目前是**未生效的遗留元数据**（与 pty 线对齐的模板残留），不得与 `CLI_VERSION=0.9.0` 混用。
2. **仓库不含 Gradle Wrapper**：无 `gradlew`/`gradle/wrapper/`；构建依赖**外部提供**的 Gradle 9.4.1（CI 用 `gradle/actions/setup-gradle@v4` 钉版；本地执行记录为 Gradle 9.4.1 + Temurin 21，见 `specs/000-scaffold/test-cases.md`）。⇒ 「干净检出可构建」依赖 runner 预装版本，属 as-built 事实，非缺陷（M1 CI 接线时维持 setup-gradle 钉版即可）。

---

## 3. 构建产物落点（as-built）

| 产物 | 落点 | 现状 | 说明 |
|---|---|---|---|
| AAR（debug 验证用） | `uv-cli/build/outputs/aar/uv-cli-debug.aar` | ✅ 产出过（TC-02，2026-11-02）；`build/` 不入库 | 配置期/打包链路验证物，非发布物 |
| AAR（release 发布物） | `uv-cli/build/outputs/aar/uv-cli-release.aar` | ⬜ 未产出（首产在 M1 CI） | 内含且仅含 `jni/arm64-v8a/libuv_cli.so`（规划 §5） |
| `libuv_cli.so` 投放位 | `uv-cli/src/main/jniLibs/arm64-v8a/` | ⬜ 当前不存在/为空（provision `--out` 写入；`.gitignore:23` 忽略） | 二进制不入库（宪法 P3） |
| fetch 工作目录 | `.dist/src/uv-src/` | ⬜ 当前不存在（脚本 exit 2 SCAFFOLD） | `.gitignore:26` 忽略 |
| cargo 构建目录 | `target/`（`--out build/out/`） | ⬜ 当前不存在 | `.gitignore:27-28` 忽略 |
| GitHub Release 归档 | `uv-cli-v<ver>-android-arm64-v8a.tar.gz` + `.sha256` | ⬜ 规划 §10.1（M1-T5） | libuv_cli.so + BUILD/FETCH-METADATA + LICENSES + cargo license 清单 |
| `META-INF/uv-cli.properties` | `uv-cli/src/main/resources/META-INF/` | ⬜ 投放时由 provision 生成（`provision.mjs:252-267`） | 字段：`tool.version`/`abi`/`name`/`size`/`sha256`/`provisionedAt` |

---

## 4. 目录 ↔ 职责 ↔ 需求映射

| 目录 / 文件 | 职责 | 需求（000-scaffold） | 现状 |
|---|---|---|---|
| `settings.gradle.kts` + `gradle.properties` + `gradle/libs.versions.toml` | Gradle 骨架与坐标元数据 | FR-000-001/002/004（spec.md 摘要口径） | ✅ |
| `uv-cli/build.gradle.kts` | AAR 容器 + `useLegacyPackaging` + 版本接线 | FR-000-002/003/004/005 | ✅ |
| `publish.gradle.kts` + `gradle.properties.local.example` | 发布面（默认禁用）与凭据卫生 | 发布卫生（宪法 P5；规划 §10.1） | ✅（发布动作 ⬜ M3） |
| `uv-cli.lock.json` | 唯一事实源 | FR-000-010~013 | ✅（draft 态） |
| `tools/provision.mjs` | 投放 + exec 门禁 | FR-000-030~036 | ✅ |
| `scripts/fetch-uv-cli-source.mjs` / `build-uv-cli-android.sh` | 构建输入与交叉编译（接口已固化） | M1 任务（规划 §10 M1-T2/T3；scaffold 仅固化接口） | ⬜（骨架 ✅） |
| `.github/workflows/build-uv-cli-android.yml` | CI 配置期门禁 | FR-000-040~042 | ✅（真实流水线 ⬜ M1） |
| `.gitignore` / `uv-cli/THIRD-PARTY-NOTICES.md` / `README*.md` / `LICENSE` | 卫生 / 许可 / 文档 | 宪法 P3/P7；规划 §12（许可门禁） | ✅ |
| `specs/` | 规格体系（本目录） | 先改文档再改实现（宪法 P8） | ✅（本批生成） |

---

## 5. 「不入库」清单（宪法 P3）

| 对象 | 位置 | 机制 | 依据 |
|---|---|---|---|
| `libuv_cli.so` | `uv-cli/src/main/jniLibs/arm64-v8a/` | `.gitignore:23`；lock 只记 `size`/`sha256`；CI 产出 + provision 投放 | 宪法 P3 · 规划 §13 |
| uv 源码与 cargo 依赖 | `.dist/`、`target/`（`~/.cargo` 缓存属 runner） | `.gitignore:26-28` | 规划 §9（缓存） |
| 构建产物 | `build/`、`.gradle/`、`*.apk`/`*.aab` | `.gitignore:2-15` | — |
| 发布凭据（Portal Token / GPG） | 用户级 `~/.gradle/gradle.properties` | 仓库只有 `gradle.properties.local.example` 模板（8 行） | 宪法 P5 · `publish.gradle.kts:12-14` |
| `libnode.so` / `libuv.so` | 任何位置 | provision `BANNED_IN_AAR=['libnode.so']`（`provision.mjs:38`）+ jniLibs 兄弟文件检查（`provision.mjs:222-225`）；`libuv.so` 命名禁区属 review 纪律 | 规划 §3.1 D6 / §5 / §12 |

---

## 6. 规划中存在、当前**不存在**的路径（防误引用）

| 规划路径 / 实体 | 规划锚点 | 现状 |
|---|---|---|
| `.dist/src/uv-src/`（uv 源码树） | §4.2 / §10 M1-T2 | ⬜ fetch 骨架 exit 2 |
| `target/aarch64-linux-android/release/uv` → `libuv_cli.so` | §4.2 ⑥ | ⬜ cargo 链未落地 |
| `.cargo/config.toml`（linker 备选接线） | §4.1（首选 cargo-ndk） | ⬜ 未创建 |
| `build/out/BUILD-METADATA.txt` / `FETCH-METADATA.json` | §4.2 ⑦ | ⬜ M1 产出 |
| GitHub Release / `.sha256` / cargo license 清单 | §10.1 | ⬜ M1-T5 |
| `matrix.allowedNeeded` 的 DT_NEEDED **实测清单回填**、lock `status=released` | §6 / §8 | ⬜ 首产后回写 |
| 真机探针 P1–P6 的回程证据 | §7.1 | ⬜ M2 |

> 全部 ⬜ 项只允许以「规划引用」出现在规格文档中，不得写成既成事实（宪法 P6/P8）。
