# constitution.md —— `aosp-uv-cli` 项目宪法（治理原则）

> 本文件是 `io.github.fellow99:uv-cli` 制品线的**最高约束**。任何 `spec.md` / `plan.md` / 实现 / 评审都必须先过这一关。
> 原则不是发明的，而是从**已落地的代码**（`tools/provision.mjs`、`uv-cli.lock.json`、Gradle 骨架）与唯一规划基线 [`../docs/000-工程规划.md`](../docs/000-工程规划.md)（v2.0，规划 §3.1 D1–D7、§13「与工作区纪律的对应」）中抽取的（依据列在每条末尾）。
> 版本：v1.0 · 2026-11-02 · 状态：**生效**
> 适用：`uv-cli/`（AAR 发布物）· `tools/` `scripts/`（host 侧工具链）· `.github/` · `specs/`

---

## 一、八条不可协商的原则

### P1. fetch 不改源（Fetch Without Modification）

**上游源码 tarball 原样使用；一切平台适配走构建配置注入，不打源码补丁。**

- uv 源码经官方 release tarball 获取、SHA-256 校验后解压；**不允许**修改任何源文件。
- 交叉编译参数只能经 cargo 配置 / `RUSTFLAGS` / 环境变量注入；uv feature 裁剪（`--no-default-features` + 手选 features）属**构建配置**而非改源。
- 任何看似「必须改源」的场景 ⇒ 先停下：找 feature/环境/配置等价机制；确实没有则回写规划拍板，不许静默改。

依据：规划 §13（fetch 不改源行）· §4.1（「交叉编译参数经 cargo 配置 / RUSTFLAGS 注入」）· `scripts/fetch-uv-cli-source.mjs:3`（「官方源码包，不改源」）。

---

### P2. lock 唯一事实源（Lock Is the Single Source of Truth）

**版本、大小、SHA-256、门禁集合、构建出处、DT_NEEDED 白名单，全部以仓库根 `uv-cli.lock.json` 为准。**

- draft 记录 `size:0` / `sha256:""` **不伪造哈希**；首个真实 CI 构建后回写并置 `status="released"`。
- 制品版本（Maven 坐标）唯一源是 `CLI_VERSION` = lock 的 release 版本；**不得**引入第二版本源（见 ⚠️ `VERSION_NAME` 观察，STRUCTURE §2.2）。
- 升级 = lock 增项 + CI 重新构建；换版本必须全门禁复跑。

依据：规划 §8（「镜像 pty/node-cli 纪律……二进制不入库」）· `uv-cli.lock.json:2`（$comment）· `tools/provision.mjs:5`（头注释）· FR-000-010~013。

---

### P3. 二进制不入库（No Binaries In Repo）

**`libuv_cli.so` 及一切构建产物、源码缓存、cargo 依赖不得进入版本库。**

- 投放位 `uv-cli/src/main/jniLibs/**/*.so` 与 `.dist/`、`build/out/`、`target/` 全部 gitignore。
- 供应链以 lock 的 size/sha256 自证；GitHub Release 归档是二进制的唯一分发位。
- 发布凭据（Portal Token / GPG）同理不入库：只从用户级 `~/.gradle/gradle.properties` 读取。

依据：`.gitignore:22-28` · 规划 §13（二进制不入库）· `gradle.properties.local.example:1`（「用户级，不提交」）· `publish.gradle.kts:13`。

---

### P4. 门禁强制（Gates Are Non-Negotiable）

**任何 `.so` 进入 AAR 前必须过 exec 型七门禁；不过即硬失败，绝不「就地找一个凑合」。**

- 七门禁：① `ET_DYN`（PIE）② **PT_INTERP 恰 1 且 = `/system/bin/linker64`** ③ AArch64 ④ DT_NEEDED ⊆ `matrix.allowedNeeded` ⑤ SHA-256（draft 仅记录）⑥ size（draft 仅记录）⑦ 16KB 页对齐。
- 退出码纪律全仓统一：`0` 全过 · `2` 门禁不合格/未投放 · `1` 用法/IO 错误；CI 必须断言「未投放 = exit 2」。
- jniLibs 兄弟文件检查（目录内仅 `libuv_cli.so`）与 `BANNED_IN_AAR=['libnode.so']` 同属门禁层。
- `--allow-page-align-4k` 仅限 bring-up 自测，发布与 16KB 设备一律不合格。

依据：`tools/provision.mjs:132-169`（门禁实现）、`:24`（退出码头注释）、`:222-225`（兄弟文件）、`:246-250`（BANNED）· 规划 §6 / §12 · workflow `:37-45`（退出码断言）· FR-000-030~036。

---

### P5. 发布卫生（Release Hygiene）

**默认不发布；凭据只存在用户级。**

- `RELEASE=false` 为仓库默认；`RELEASE=true` **且** Portal Token 齐备才启用 Central/签名任务（`publish.gradle.kts:71-73,133-139`）。
- 两段式发布：GitHub Release 先行（归档 + `.sha256` + license 清单，lock 回写 `released`）⇒ Maven Central 随后（M3，按 workspace runbook）。
- Maven 阶段发布前检查：provision `--check` 全过 + lock `status=released`。

依据：`gradle.properties:18-19` · 规划 §5（Maven 阶段发布前检查）/ §10.1（两段式）/ §12（发布卫生行）。

---

### P6. 未实测 ⬜（Untested Must Be Marked）

**凡未在本仓实测的结论，一律标 ⬜，绝不当作已定事实引用。**

- 证据标记四种：✅ 实测（本仓可复核）/ 🔶 沿用（同族工程一手记录，本仓未复现）/ ⬜ 待验证 / ⚠️ 冲突或风险。
- 首个真实产物出现前：size/sha256/DT_NEEDED 实测清单/rust 与 NDK 版本/体积量级/TLS 根证书生效性，**全部 ⬜**。
- `🔶 沿用` 的结论不得作为本仓对外承诺的依据（pty 线验证过的门禁算法可以沿用实现，但 uv 产物必须自己过一遍门禁）。

依据：规划文件头（「纪律：⬜ 为未实测项，绝不当作已定事实引用」）· §11（R1–R8 全部 ⬜）· specs 各文档标记口径。

---

### P7. 不下载上游二进制（No Upstream Binaries, Ever）

**uv 上游没有 Android 官方产物 ⇒ 本仓一律 CI 源码自建；可执行代码不从网上下载，构建期与运行期同纪律。**

- 构建期：只下载**源码** tarball（SHA-256 校验）+ crates.io 依赖（Cargo.lock 钉版）；绝不拉取/改名任何上游平台二进制。
- 运行期：`uv python install` / managed python **禁用**（运行期下载可执行 = 红线；python-build-standalone 构件亦非 Android 形态）。
- 该边界的运行期表达属**消费方文档义务**（M2 回写 README）。

依据：规划 §1.2（「上游无 Android 官方产物 ⇒ 一律 CI 源码自建（C2 纪律：不下载上游二进制，构建期也不引入）」）· §3.1 D3/D7 · §7 已知限制 1 · workspace 方案 §9。

---

### P8. 先改文档再改实现（Docs Before Code）

**唯一规划基线是 `docs/000-工程规划.md`（v2.0）；实现与本文件的偏差随里程碑直接回写。**

- 任何新平台结论、决策变更（含 D1–D7 的修订、降级路径拍板、依赖 sha 粒度方案 A/B）⇒ **先改规划文件，再动实现**。
- 规格文档（本目录）只做收敛/展开与验收判据，回引规划 § 号，**不复制粘贴**，避免两份文档漂移。
- 规划中 ⬜ 的设计（M1/M2/M3/M4）在规格里只能以「规划引用」出现。

依据：规划文件头（「唯一规划基线，变更走『先改本文件，再改实现』」）· §4.4/§4.3（降级路径「先回写本文件再动实现」）· §8（「拍板后回写本文件」）。

---

## 二、规约（从现有代码抽取，实现必须一致）

| # | 规约 | 现状依据 |
|---|---|---|
| S1 | **退出码纪律**：host 工具 `0` 全过 / `2` 门禁不合格或未投放 / `1` 用法或 IO 错误；CI 断言「未投放 = 2」 | `provision.mjs:24` · workflow `:37-45` |
| S2 | **exec 型命名**：产物唯一名 `libuv_cli.so`（DEFAULT_BINARY）；禁区 `libuv.so`（与 libuv 库混淆）/ `libnode.so`（引擎占用） | `provision.mjs:36,38` · 规划 §3.1 D6 |
| S3 | **jniLibs 单文件**：投放目录内除本工具二进制外不得出现任何 `.so`（兄弟文件检查） | `provision.mjs:222-225` |
| S4 | **版本属性命名 `CLI_VERSION`**（不占用 Gradle 保留前缀）；坐标版本唯一取该属性，缺失即配置期 `error()` | `uv-cli/build.gradle.kts:16-17` · `publish.gradle.kts:37-39` |
| S5 | **极简 ELF64 解析**：provision 内置小端 ELF 解析，零第三方依赖（与 workspace 各仓 provision 同族），只回答门禁需要的问题 | `provision.mjs:56-130` |
| S6 | **draft 语义**：`size=0`/`sha256=""` 表示「未构建」，工具只记录不比对；**禁止**占位哈希 | `provision.mjs:141-142,156-159` · lock `:13-14` |
| S7 | **脚本骨架纪律**：未实现的构建脚本必须显式 `exit 2`（SCAFFOLD）并打印计划输入/输出，不得假装成功 | `fetch-uv-cli-source.mjs:46-53` · `build-uv-cli-android.sh:55-58` |
| S8 | **配置期可求值**：无 `.so` 时 Gradle 配置/任务必须成功（二进制缺失不阻碍配置期） | FR-000-005 · workflow `:34-35` · TC-01/02 |
| S9 | **元数据随投放生成**：`META-INF/uv-cli.properties`（tool.version/abi/name/size/sha256/provisionedAt）只由 provision 写 | `provision.mjs:252-267` |
| S10 | **中文注释 + 英文术语**：构建脚本头注释固化不可回归纪律（rust/cargo-ndk 七条），供 M1 实现对齐 | `build-uv-cli-android.sh:5-13` |

---

## 三、证据纪律（Evidence Discipline）

1. 每条非显然结论带 ✅/🔶/⬜/⚠️ 之一（口径见 P6）；**不要把推断当实测**。
2. 源文件行号注明快照日期（本文档体系 = **2026-11-02**）；行号仅作定位线索，以函数/常量名为准。
3. 「门禁全过」不等于「真机可用」：exec 产物在设备上的回程证据（`uv --version`、venv、HTTPS、组合链路）只能来自 M2 真机探针 P1–P6 ⬜。

---

## 四、评审清单（Reviewer Checklist）

评审任何 `spec.md` / `plan.md` / PR 时逐条问：

- [ ] 是否修改了上游源码？（P1——feature/配置等价机制找过没有）
- [ ] 版本/哈希/门禁/出处是否只认 lock？（P2——有没有第二版本源）
- [ ] 是否有二进制/凭据进入版本库的风险？（P3/P5）
- [ ] 门禁是否可被绕过（新投放路径、白名单扩展、对齐放行）？（P4）
- [ ] 是否有「未实测却写成事实」的断言？（P6）
- [ ] 是否引入任何「下载可执行」的路径（构建期或运行期）？（P7）
- [ ] 决策变更是否先回写了 `docs/000-工程规划.md`？（P8）
- [ ] 每条 FR 的验收判据是否可证伪、有二元出口？

---

## 五、变更流程

1. **改 D1–D7 任一决策 / 降级路径拍板 / 依赖 sha 粒度方案** ⇒ 先改 `docs/000-工程规划.md` 对应 §，再改实现与 lock（P8）。
2. **换/增 uv 版本** ⇒ lock 增项（draft）→ CI 构建 → provision 全门禁 → 回写 size/sha256/DT_NEEDED 实测清单/builtFrom → `status=released`；README 版本表同步。
3. **扩 `matrix.allowedNeeded`**（白名单新增随包库）⇒ 属门禁语义变更：先改规划 §6/§8，再改 lock，并在 specs 各文档同步「不随包」口径（当前唯一登记项 `libc++_shared.so` 实际**不随包**，D5）。
4. **改发布面**（coordinates/插件版本/签名策略）⇒ 同步 `publish.gradle.kts`、`gradle.properties`、README 与本目录 TECH.md §1。
