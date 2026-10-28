import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingFile = rootProject.file("key.properties")
val releaseKeys = Properties()
if (signingFile.exists()) {
    signingFile.inputStream().use { releaseKeys.load(it) }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach {
        require(!releaseKeys.getProperty(it).isNullOrBlank()) { "Missing release signing property: $it" }
    }
    val configuredStore = rootProject.file(releaseKeys.getProperty("storeFile"))
    require(configuredStore.isFile) { "Configured production keystore does not exist." }
    require(!configuredStore.name.equals("debug.keystore", ignoreCase = true) &&
        !releaseKeys.getProperty("keyAlias").equals("androiddebugkey", ignoreCase = true)) {
        "The Android debug keystore/alias cannot be used for a production release."
    }
}

// Evaluate the graph, including aggregate commands such as `gradlew assemble`,
// before any packaging tasks run. Debug builds remain usable without secrets.
gradle.taskGraph.whenReady {
    val packagesRelease = allTasks.any {
        it.project.path == project.path &&
            it.name.matches(Regex("(assemble|bundle|package).*Release.*"))
    }
    require(!packagesRelease || signingFile.isFile) {
        "Production signing is required. Run python3 tools/setup_android_signing.py in your own terminal before building a release."
    }
}

android {
    namespace = "com.xennzeru.xenndo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.xennzeru.xenndo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingFile.exists()) {
            create("release") {
                storeFile = rootProject.file(releaseKeys.getProperty("storeFile"))
                storePassword = releaseKeys.getProperty("storePassword")
                keyAlias = releaseKeys.getProperty("keyAlias")
                keyPassword = releaseKeys.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Missing signing is rejected above; never fall back to debug.
            signingConfig = signingConfigs.findByName("release")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
