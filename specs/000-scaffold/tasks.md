# 000-scaffold 任务拆解

> 对应：[spec.md](./spec.md)。原则：骨架完整、简单编译通过；真实交叉编译属 M1。

- [x] T1 Gradle 骨架（settings/toml/properties/local.example/publish/模块 build，
      **useLegacyPackaging=true**，CLI_VERSION=0.9.0 draft）
- [x] T2 `uv-cli.lock.json`（draft；allowedNeeded 含 libc++_shared.so）
- [x] T3 `tools/provision.mjs`（exec profile 同款；禁入 libnode.so；META-INF/uv-cli.properties）
- [x] T4 脚本骨架：`fetch-uv-cli-source.mjs` / `build-uv-cli-android.sh`（rust/cargo-ndk 七条纪律注释）
- [x] T5 scaffold CI（配置期门禁 + 自检）
- [x] T6 `.gitignore`（含 target/）/ THIRD-PARTY（uv 双许可）/ README 中英 / docs/000
- [x] T7 specs（三件套）
- [x] T8 验证（assembleDebug + provision 退出码 + 语法门）+ 提交（父工程不提交）
