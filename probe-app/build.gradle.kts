// probe-app —— 003-cli App 域探针载体（FR-003-050~055 / tasks T11）
// 独立 Gradle 工程（不在 aosp-uv-cli settings.gradle 内——000 的单模块红线不动）。
// 依赖本仓 CI/本地产物 AAR：provision --out 投放 + assembleRelease 产出 uv-cli-release.aar 放 app/libs/ 后构建。
plugins {
    id("com.android.application") version "9.2.1" apply false
}
