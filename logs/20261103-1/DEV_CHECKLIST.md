# DEV_CHECKLIST — 20261103-1（开发阶段执行清单）

> 工程：aosp-uv-cli · 分支：main（需求方指定不改动）· 依据：specs/001/002/003 四件套（commit 2936c0d）。
> 环境：Windows host（Git Bash + Node 24 + NDK 28.2.13676358 + rustup stable 1.99.1）；模拟器 Medium_Phone_API_37.0 在线。

## 001-building（fetch / 工具链 / 编译 / 整理）

- [ ] T1 fetch 真实实现（PINS 0.13.6 + 幂等 + FETCH-METADATA）→ TC-001-01~07
- [ ] T3/T4 rust 工具链 + NDK/cc 环境 + RUSTFLAGS 16KB → TC-001-08/10/12
- [ ] T5 C 依赖试编探针（aws-lc-rs 1.18 在树实测，R2）→ TC-001-11
- [ ] T6/T7/T8 编译 + DT_NEEDED 记录 + strip/改名/体积 → TC-001-13/14/17
- [ ] T9/T10 BUILD-METADATA + 门禁自检 + 投放 → TC-001-15
- [ ] T11 lock 回写素材 → TC-001-16

## 002-building-workflow（lock 回写 / CI）

- [ ] T1/T2 tools/lock-writeback.mjs（守卫矩阵）→ TC-002-01~09
- [ ] T4 workflow 重写（config-check 保留 + build-android-arm64）→ TC-002-10~12
- [ ] T5 退出码断言修复 → TC-002-13
- [ ] T6/T7/T8 归档 + tag 门 + 缓存 → TC-002-14/16
- [ ] T9 语法门扩展 → TC-002-15
- [ ] 版本钉选回写：CLI_VERSION/lock 0.13.6 + 规划 §2/§4.1/§4.3（P8）✅ 已改
- [ ] VERSION_NAME=0.1.0 清理（000-scaffold §8-9）✅ 已删

## 003-cli（harness）

- [ ] T1 scripts/test-on-device/ 三件（run-probes/probe-lib/env-contract）
- [ ] T2~T10 用例实现（TC-003-00~17 载体：run-probes.sh 内置）

- [x] 版本钉选回写：CLI_VERSION/lock 0.13.6 + 规划 §2/§4.1/§4.3（P8）
- [x] VERSION_NAME=0.1.0 清理（000-scaffold §8-9）

## 阶段记录

- 2026-11-03：aws-lc-rs 1.18.0 + aws-lc-sys 0.44.0 实测在 Cargo.lock；uv workspace Cargo.toml 硬编码 rustls `aws_lc_rs` feature；host 无 cmake；VS 2019 空目录无 link.exe ⇒ 本地 host 工具链切 windows-gnu（rust-mingw 自带链接器），CI（ubuntu-gnu）不受影响。
