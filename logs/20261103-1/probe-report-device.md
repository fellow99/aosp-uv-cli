# probe-report-device — 2026-11-03T04:33:31Z

- 设备：sdk_gphone64_x86_64（emulator-5554）· ABI=x86_64 · API=37 · PAGESIZE=4096 · 载体=ndk_translation(host=x86_64,abi=x86_64) · 农场=copy(ok=0)
- 制品：libuv_cli.so host_sha=c6d9edfd1642e03fde1308b91ad4f57382a1925f38f0b83da0063b4ddaabcfb1 device_sha=c6d9edfd1642e03fde1308b91ad4f57382a1925f38f0b83da0063b4ddaabcfb1
- 汇总：PASS=6 FAIL=0 SKIP=11（明细见 probe-report-device.json）

- **TC-003-00** [PASS] 部署自检 `env-ok`
- **TC-003-00b** [INFO] 环境快照 `CARRIER=ndk_translation(host=x86_64,abi=x86_64) FARM=copy/ok=0 x86_64 x86_64 37 4096 Enforcing u:object_r:shell_data_fil`
- **TC-003-01** [PASS] 版本回程直呼（P1） `uv 0.13.6 (aarch64-linux-android)`
- **TC-003-01b** [SKIP] 版本回程农场直呼（P1）（载体域限制：ndk_translation 对 PATH 名字查找 exec 报 linker realpath 错（实测记录）；真机域恢复）
- **TC-003-02** [PASS] 帮助直出 `help-ok`
- **TC-003-03** [PASS] cache dir 注入（P5） `cache-ok`
- **TC-003-04** [INFO] 退出码采样 `error: unexpected argument '--bogus-flag' found  Usage: libuv_cli.so [OPTIONS] <COMMAND>  For more information, try '--h`
- **TC-003-05** [SKIP] venv 创建（P2）（python-cli 解释器不可得；无解释器失败形态已记录（No interpreter found）；真机+python-cli 域恢复）
- **TC-003-06** [INFO] venv 指定解释器失败形态 `error: No interpreter found for Python 3.12 in managed installations or search path  hint: uv embeds available Python do`
- **TC-003-07** [SKIP] pip install 纯 wheel HTTPS（P3/rustls）（设备网络不可达）
- **TC-003-08** [SKIP] pip list/uninstall 闭环（依赖 TC-003-07（网络））
- **TC-003-09** [SKIP] sdist 拒收事实化（依赖网络）
- **TC-003-10** [PASS] uv python install 禁用（C2/D7） `error: No download found for request: cpython-3.12-linux-aarch64-none`
- **TC-003-11** [SKIP] cache 增量核验（依赖网络）
- **TC-003-12a** [INFO] LD_LIBRARY_PATH 反证①去注入 `uv 0.13.6 (aarch64-linux-android) exit=0`
- **TC-003-12b** [SKIP] LD_LIBRARY_PATH 反证②注入libc++（DT_NEEDED 实测不含 libc++_shared.so（静态链命中，见 BUILD-METADATA dtNeeded）——本条记录性，无需反证）
- **TC-003-13** [SKIP] SSL_CERT_FILE 反证（依赖网络）
- **TC-003-14** [SKIP] UV_PYTHON 组合（P4）（未提供 --python-cli-interp（python-cli 物化产物））
- **TC-003-15** [SKIP] git 依赖源限制（依赖网络（git 源解析在安装链路前端））
- **TC-003-16** [PASS] XDG 兜底 `xdg-ok=/data/local/tmp/uv-probe/xdg/uv`
- **TC-003-17** [SKIP] 16KB 页采样（页大小=4096（非 16KB 设备））
