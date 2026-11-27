import java.io.File
import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名只从 android/key.properties 读取；该文件和 keystore 都不进 Git。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }
val hasReleaseSigning = releaseStoreFile?.exists() == true &&
    !keystoreProperties.getProperty("keyAlias").isNullOrBlank() &&
    !keystoreProperties.getProperty("storePassword").isNullOrBlank() &&
    !keystoreProperties.getProperty("keyPassword").isNullOrBlank()

android {
    namespace = "com.otimeum.laetibeat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.otimeum.laetibeat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Laetibeat"
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    packaging {
        jniLibs {
            // 内置 Rust sidecar 以 .so 形式打包，必须解压后执行。
            useLegacyPackaging = true
        }
    }

    buildTypes {
        debug {
            // 与日常 release 并存安装，flutter run 不会覆盖日常版本。
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            manifestPlaceholders["appLabel"] = "Laetibeat Debug"
        }
        release {
            manifestPlaceholders["appLabel"] = "Laetibeat"
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // 通知图标通过资源名字符串在运行时查找，资源名混淆后
            // audio_service 会找不到 drawable/ic_stat_playback。
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // rustls-platform-verifier 的 Android JVM 组件。
    // 版本必须与 Cargo.lock 中的 rustls-platform-verifier-android 对齐。
    implementation("org.rustls:rustls-platform-verifier:0.2.0")
}

val repoRoot = rootProject.projectDir.parentFile.parentFile

fun androidNdkHostTag(): String {
    val os = System.getProperty("os.name").lowercase()
    return when {
        os.contains("mac") -> "darwin-x86_64"
        os.contains("windows") -> "windows-x86_64"
        else -> "linux-x86_64"
    }
}

// 把 QQ / 网易云 Rust sidecar 编译进 jniLibs。cargo 产物是 PIE 可执行文件，
// 以 lib*.so 命名并解压安装。
data class RustHostAbi(
    val abi: String,
    val target: String,
    val envSuffix: String,
    val clang: String,
    val maxPageSize: String,
)

val rustHostAbis = listOf(
    RustHostAbi(
        "arm64-v8a",
        "aarch64-linux-android",
        "aarch64_linux_android",
        "aarch64-linux-android24-clang",
        "16384",
    ),
    RustHostAbi(
        "armeabi-v7a",
        "armv7-linux-androideabi",
        "armv7_linux_androideabi",
        "armv7a-linux-androideabi24-clang",
        "4096",
    ),
    RustHostAbi(
        "x86_64",
        "x86_64-linux-android",
        "x86_64_linux_android",
        "x86_64-linux-android24-clang",
        "16384",
    ),
)

val rustOnlineHosts = listOf("qq", "netease")

val rustHostTasks = rustHostAbis.map { target ->
    val jniDir = file("src/main/jniLibs/${target.abi}")
    val taskName =
        "buildRustOnlineHosts" +
            target.abi.split('-', '_').joinToString("") { part ->
                part.replaceFirstChar { it.uppercase() }
            }
    tasks.register<Exec>(taskName) {
        group = "flutter"
        description = "Build QQ / NetEase Rust sidecars for Android ${target.abi}"
        workingDir = repoRoot
        val clangFile = File(
            android.sdkDirectory,
            "ndk/${flutter.ndkVersion}/toolchains/llvm/prebuilt/" +
                "${androidNdkHostTag()}/bin/${target.clang}",
        )
        val arFile = File(clangFile.parentFile, "llvm-ar")
        val ranlibFile = File(clangFile.parentFile, "llvm-ranlib")
        val linkerEnv =
            "CARGO_TARGET_${target.target.uppercase().replace('-', '_')}_LINKER"
        doFirst {
            if (!clangFile.exists()) {
                throw GradleException("找不到 Android NDK clang：${clangFile.absolutePath}")
            }
            jniDir.mkdirs()
        }
        environment("CC_${target.envSuffix}", clangFile.absolutePath)
        environment("AR_${target.envSuffix}", arFile.absolutePath)
        environment("RANLIB_${target.envSuffix}", ranlibFile.absolutePath)
        environment(linkerEnv, clangFile.absolutePath)
        environment(
            "RUSTFLAGS",
            "-C strip=symbols -C link-arg=-Wl,-z,max-page-size=${target.maxPageSize}",
        )
        commandLine(
            "cargo",
            "build",
            "--release",
            "-p",
            "laetibeat_qq_host",
            "-p",
            "laetibeat_netease_host",
            "--target",
            target.target,
        )
        doLast {
            rustOnlineHosts.forEach { host ->
                val source = File(
                    repoRoot,
                    "target/${target.target}/release/laetibeat_${host}_host",
                )
                if (!source.exists()) {
                    throw GradleException("Rust sidecar 构建产物不存在：${source.absolutePath}")
                }
                val output = File(jniDir, "liblaetibeat_${host}_host.so")
                source.copyTo(output, overwrite = true)
                output.setExecutable(true, false)
            }
        }
        inputs.files(
            File(repoRoot, "Cargo.toml"),
            File(repoRoot, "Cargo.lock"),
            fileTree(File(repoRoot, "laetibeat_qq_host")) {
                include("**/*.rs", "Cargo.toml")
                exclude("target/**")
            },
            fileTree(File(repoRoot, "laetibeat_netease_host")) {
                include("**/*.rs", "Cargo.toml")
                exclude("target/**")
            },
        )
        outputs.files(
            *rustOnlineHosts.map { host ->
                File(jniDir, "liblaetibeat_${host}_host.so")
            }.toTypedArray(),
        )
    }
}

tasks.named("preBuild").configure {
    dependsOn(rustHostTasks)
}

val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release")
}
if (requestedReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "正式 release 缺少签名配置。请创建 android/key.properties，并确保 storeFile 指向存在的 keystore；参考 android/key.properties.example。",
    )
}
