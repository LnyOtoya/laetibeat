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
            // 内置 go-music-api host 以 .so 形式打包，必须解压后执行。
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

// 把 Go host 编译进 jniLibs/arm64-v8a。Android 上 Go 的纯 Go DNS
// 不可用，必须用 NDK clang + CGO 构建 PIE。
val repoRoot = rootProject.projectDir.parentFile.parentFile
val musicApiHostDir = File(repoRoot, "laetibeat_musicapi_host")
data class MusicApiAbi(
    val abi: String,
    val goArch: String,
    val goArm: String?,
    val clang: String,
)

val musicApiAbis = listOf(
    MusicApiAbi("arm64-v8a", "arm64", null, "aarch64-linux-android24-clang"),
    MusicApiAbi("armeabi-v7a", "arm", "7", "armv7a-linux-androideabi24-clang"),
    MusicApiAbi("x86_64", "amd64", null, "x86_64-linux-android24-clang"),
)

fun androidNdkHostTag(): String {
    val os = System.getProperty("os.name").lowercase()
    return when {
        os.contains("mac") -> "darwin-x86_64"
        os.contains("windows") -> "windows-x86_64"
        else -> "linux-x86_64"
    }
}

val musicApiHostTasks = musicApiAbis.map { target ->
    val jniDir = file("src/main/jniLibs/${target.abi}")
    val output = File(jniDir, "liblaetibeat_musicapi_host.so")
    val taskName =
        "buildMusicApiHost" +
            target.abi.split('-', '_').joinToString("") { part ->
                part.replaceFirstChar { it.uppercase() }
            }
    tasks.register<Exec>(taskName) {
        group = "flutter"
        description = "Build embedded go-music-api host for Android ${target.abi}"
        workingDir = musicApiHostDir
        val clangFile = File(
            android.sdkDirectory,
            "ndk/${flutter.ndkVersion}/toolchains/llvm/prebuilt/" +
                "${androidNdkHostTag()}/bin/${target.clang}",
        )
        doFirst {
            if (!clangFile.exists()) {
                throw GradleException("找不到 Android NDK clang：${clangFile.absolutePath}")
            }
            jniDir.mkdirs()
        }
        environment("CGO_ENABLED", "1")
        environment("GOOS", "android")
        environment("GOARCH", target.goArch)
        target.goArm?.let { environment("GOARM", it) }
        environment("CC", clangFile.absolutePath)
        commandLine(
            "go",
            "build",
            "-buildmode=pie",
            "-trimpath",
            "-ldflags",
            "-s -w",
            "-o",
            output.absolutePath,
            ".",
        )
        inputs.files(
            fileTree(musicApiHostDir) {
                include("**/*.go", "go.mod", "go.sum")
                exclude("build/**", "bin/**")
            },
        )
        outputs.file(output)
    }
}

tasks.named("preBuild").configure {
    dependsOn(musicApiHostTasks)
}

val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release")
}
if (requestedReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "正式 release 缺少签名配置。请创建 android/key.properties，并确保 storeFile 指向存在的 keystore；参考 android/key.properties.example。",
    )
}
