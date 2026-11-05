# aosp-uv-cli

[English](README.md) · [**中文**](README_zh.md)

**The Android `uv` command-line executable, packaged as an AAR** — a Rust cross-compiled
`libuv_cli.so` (arm64-v8a, exec-form PIE, official tier2 target `aarch64-linux-android`)
with TLS via rustls bundled roots. Launched from the terminal by node-pty via
`forkpty` + `execve`, providing a real `uv` command (python environments / package management).

This repository contains no embedding API — only the reproducible build, ELF gates and
release pipeline for the native binary. Planning baseline:
[`docs/000-工程规划.md`](docs/000-工程规划.md); workspace-level rationale: the
node-bridge-workspace doc `docs/aosp+node+python+git运行方案.md`.

## Version: follows upstream uv (independent semver)

The artifact version = the uv upstream version. No pairing with other repos.
**AArch64 (arm64-v8a) only**. Upstream ships no Android artifacts ⇒ this repo builds from
source in CI (discipline: never download upstream binaries).

### Releases — Maven Central (`io.github.fellow99:uv-cli`)

| Version | Status | Link |
|---|---|---|
| 0.9.0 | ⬜ draft (after the first M1 build; the CI-pinned uv version prevails) | — |

## Build profile (key points)

- `rustup target add aarch64-linux-android` + cargo-ndk (NDK linker);
- `-C link-arg=-Wl,-z,max-page-size=16384` (hard requirement on 16KB-page devices);
- compilability of C deps (ring/zstd) is a pre-M1 probe;
- exec-form ELF: PIE + PT_INTERP=`/system/bin/linker64`;
- named `libuv_cli.so` (**never** confuse with the libuv library).

## Usage (consumers)

```kotlin
dependencies {
    runtimeOnly("io.github.fellow99:uv-cli:0.9.0") // independent version, not paired with the node family
}
```

Terminal side: with `PATH` pointing at `nativeLibraryDir`, `uv venv` / `uv pip install`
work directly; combined with `python-cli` (aosp-python-cli) it forms a full python toolchain.

## Capability boundary (honest disclosure; basis: workspace `docs/20261105-cli-实测问题-修复设计.md` §2.2/§4.3)

This AAR ships the **uv command itself** (exec-form). Capability boundaries are disclosed as facts:

| Capability | Boundary |
|---|---|
| Pure-Python wheel packages | ✅ installable: `uv pip install <pure-py-pkg>` (e.g. `six`/`packaging`) |
| Packages with C/Rust extensions (e.g. `fastapi`→`pydantic-core`) | ⚠️ installable only if a matching `cpython-3.14-aarch64-linux-android` wheel exists; **currently ≈ not installable** (`pydantic-core` has no android wheel) |
| sdist (source) | ⛔ cannot be compiled on device |
| No compiler on device | ⛔ source-build fallback not viable |
| `uv python install` (managed python) | ⛔ unsupported (C2 red line: no runtime executable downloads; no android managed python upstream) |
| Interpreter discovery | uv inspects interpreters in **isolation mode** and **ignores `PYTHONHOME`**; a non-self-consistent prefix (missing stdlib, etc.) fails ⇒ **depends on a self-consistent prefix** from the environment bootstrap layer (fix-design §4.2 C1) |

> On-device usage: `uv venv` / `uv pip` need `UV_PYTHON` pointing at a **self-consistent prefix**
> (python-cli interpreter + stdlib, fix-design §4.2); the pure-py domain works; packages with native
> extensions sit at an ecosystem boundary (E1 disclosed, fix-design §2.2/§5-4).

## Exec-form packaging points

- **`useLegacyPackaging=true`** (must be physically extracted to `nativeLibraryDir`,
  otherwise `execve` ENOENT);
- PT_INTERP must be `/system/bin/linker64` (hard gate);
- DT_NEEDED whitelist (system libs + `libc++_shared.so`, supplied by the consumer's
  node-runtime);
- 16KB page alignment.

## How to build (000-scaffold skeleton; real pipeline lands in M1)

```bash
node scripts/fetch-uv-cli-source.mjs --uv 0.9.0 --out .dist/src   # M1
bash scripts/build-uv-cli-android.sh --uv 0.9.0 --api 24 \
  --src .dist/src/uv-src --ndk "$ANDROID_NDK_HOME" --out build/out  # M1
node tools/provision.mjs --out uv-cli/src/main/jniLibs --from build/out/libuv_cli.so
node tools/provision.mjs --check
```

## Lock & verification

[`uv-cli.lock.json`](uv-cli.lock.json) (single source of truth, currently draft).
Exit codes: `0` pass · `2` gate failure / not provisioned · `1` usage/IO error.

## License

[MIT](LICENSE). uv is dual-licensed MIT OR Apache-2.0 — see
[`uv-cli/THIRD-PARTY-NOTICES.md`](uv-cli/THIRD-PARTY-NOTICES.md).
