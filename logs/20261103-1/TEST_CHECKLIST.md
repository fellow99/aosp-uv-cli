# TEST_CHECKLIST — 20261103-1（测试阶段执行清单）

> 工程：aosp-uv-cli · 依据：specs/000~003 各 test-cases.md · 执行环境三域：
> ① host（Windows Git Bash + Node 24）② CI（GitHub Actions ubuntu-24.04，run 41574193742 ✅）
> ③ 设备（模拟器 emulator-5554，Medium_Phone_API_37.0，x86_64 + ndk_translation，API 37 / 4K 页）

## L1a/L1b host 侧（000/001/002 用例）

- [x] TC-000-01~05（回归）：`gradle :uv-cli:tasks` 过 / `--check`=2 / 语法门 ×5 / git 卫生 ✅
- [x] TC-001-01 语法门（fetch/build/lock-writeback/harness ×5）✅
- [x] TC-001-02 首次取源 ✅（`.dist/src/uv-src/` + FETCH-METADATA）
- [x] TC-001-03 幂等跳过 ✅（缓存命中日志）
- [x] TC-001-04 损坏自愈 ✅（篡改 1 字节 → 重下 → exit 0）
- [x] TC-001-05 篡改拒绝 ✅（错 pin → exit 2 + 删缓存，隔离目录实测）
- [x] TC-001-06 未登记版本 ✅（exit 2）
- [x] TC-001-07 Cargo.lock sha256 复算一致 ✅（968afc76…8d0a）
- [x] TC-001-14 七门禁自检 ✅（CI + host 双复验，①②③④⑤⑥⑦ 全 ✔）
- [x] TC-002-01 语法门 ✅ / TC-002-10 YAML 静态检查 ✅ / TC-002-13 断言口径 ✅（CI config-check 绿）
- [ ] TC-001-08~13/15~17、TC-002-02~09/11/12/14~16：并入 CI 全链判定（build 步 success = strip/门禁/素材生成全过；lock-writeback 干跑 success = 守卫矩阵过）——见 TEST_REPORT §二

## L2 CI 端到端（run 41574193742，commit 6788d0a）

- [x] fetch（sha256 门）✅ → build（试编探针 + cargo build --locked + strip + 改名 + 门禁自检）✅
- [x] 归档（tar.gz + .sha256 + LICENSES + cargo 许可清单）✅ → lock 回写干跑 ✅ → artifact 上传 ✅
- [x] Release skipped（非 tag 触发，P5 发布卫生正确生效）✅
- [x] 制品：`libuv_cli.so` 34,979,336 B / sha256 c6d9edfd1642e03fde1308b91ad4f57382a1925f38f0b83da0063b4ddaabcfb1 / DT_NEEDED=[libdl,libm,libc]

## L3 设备探针（003 主用例全集 TC-003-00~17）

- [x] 全量执行（run-probes.sh）→ **PASS=6 / FAIL=0 / SKIP=11**（SKIP 全部带归因）✅
- [x] P1 版本回程 ✅（`uv 0.13.6 (aarch64-linux-android)`）
- [x] P5 cache 注入 ✅（输出逐字符等于 UV_CACHE_DIR）
- [x] C2/D7 红线事实化 ✅（上游无 android managed python 下载）
- [x] XDG 兜底 ✅（`<XDG_CACHE_HOME>/uv` 形态）
- [x] P2/P3/P4/P6/farm 通路：SKIP（载体域限制/网络/python-cli 不可得，真机域待验）——不判 FAIL（判据不可达≠不达标）
