plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.sysleaf.sysleaf"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    defaultConfig {
        applicationId = "dev.sysleaf.sysleaf"
        minSdk = 30
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release {
            // Local installable builds use the debug key. Supply your own key
            // before distributing a production release.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter { source = "../.." }

val rustTargets = (project.findProperty("target-platform") as String? ?: "android-arm,android-arm64,android-x64")
    .split(",").mapNotNull {
        when (it.trim()) {
            "android-arm" -> "armeabi-v7a"
            "android-arm64" -> "arm64-v8a"
            "android-x64" -> "x86_64"
            else -> null
        }
    }.distinct()

// Do not advertise an ABI merely because a Rust library from an earlier
// universal build remains in jniLibs; its Flutter engine may not be present.
android.defaultConfig.ndk.abiFilters.clear()
android.defaultConfig.ndk.abiFilters.addAll(rustTargets)

// Keep each requested ABI set in its own generated directory. Flutter adds
// default ABI filters during variant setup, so stale .so files in src/jniLibs
// must not be used as an input to an ARM64-only APK.
val rustLibraryDir = layout.buildDirectory.dir("rust-jni/${rustTargets.joinToString("_")}").get().asFile
android.sourceSets.getByName("main").jniLibs.setSrcDirs(listOf(rustLibraryDir))

val buildRust by tasks.registering(Exec::class) {
    group = "build"
    description = "Build the Rust core for the requested Android ABIs"
    workingDir = file("../../rust")
    inputs.files(fileTree("../../rust/src"), file("../../rust/Cargo.toml"), file("../../rust/Cargo.lock"), file("../../rust/.cargo/config.toml"))
    inputs.property("abis", rustTargets.joinToString(","))
    outputs.dir(rustLibraryDir)
    environment("ANDROID_NDK_HOME", "${android.sdkDirectory}/ndk/${android.ndkVersion}")
    commandLine(listOf("cargo", "ndk") + rustTargets.flatMap { listOf("-t", it) } +
        listOf("-o", rustLibraryDir.absolutePath, "build", "--release", "--locked"))
}
tasks.named("preBuild") { dependsOn(buildRust) }
