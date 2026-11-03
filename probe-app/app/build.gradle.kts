plugins {
    id("com.android.application")
}

android {
    namespace = "org.fellow99.uvprobe"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.fellow99.uvprobe"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "0.13.6-probe"
        // 仅 arm64：验证 exec 型产物（x86_64 模拟器经 ndk_translation 可装可跑，abilist 含 arm64-v8a）
        ndk { abiFilters += "arm64-v8a" }
    }

    // 与容器 AAR 同口径：exec 要求物理落盘 nativeLibraryDir（D1）
    packaging {
        jniLibs { useLegacyPackaging = true }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        getByName("debug") {
            isDebuggable = true
        }
    }
}

dependencies {
    // 本仓产物 AAR（jni/arm64-v8a/libuv_cli.so 随 APK 合并；M0 骨架 AAR 无 Kotlin/Java 源）
    implementation(files("libs/uv-cli-release.aar"))
}
