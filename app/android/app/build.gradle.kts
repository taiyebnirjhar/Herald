import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key. Locally: app/android/key.properties (git-ignored).
// In CI: written from GitHub Actions secrets by .github/workflows/app.yml.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
val hasReleaseKey = keyPropertiesFile.exists()
if (hasReleaseKey) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "com.taiyebnirjhar.herald"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.taiyebnirjhar.herald"
        // PLAN.md D2: targetSdk 28 is deliberate. Android 10+ blocks executing
        // binaries from app data when targetSdk >= 29, and Hermes needs proot.
        // Do not raise this without reading docs/DECISIONS.md.
        minSdk = 29
        targetSdk = 28
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // PLAN.md §2: arm64-v8a only.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    // The proot pieces (runtime/proot/) are native libraries. They are extracted to the
    // app's native library folder, where Android allows them to run.
    sourceSets {
        getByName("main") {
            jniLibs.srcDir("../../../runtime/proot/jniLibs")
        }
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// targetSdk 28 is intentional (PLAN.md D2). Lint's Google Play "target API 33+" rule
// is therefore disabled. It is the only lint rule turned off; all others stay on.
android.lint {
    disable += "ExpiredTargetSdkVersion"
}

// Never produce a release APK that is unsigned or debug-signed. A debug key
// differs on every CI runner, so updates would fail to install over the top.
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { it.name.contains("Release") }
    if (releaseRequested && !hasReleaseKey) {
        throw GradleException(
            "Release signing key missing. Add app/android/key.properties " +
                "(see README: 'Signing key'). Refusing to build an unsigned release."
        )
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
    implementation("org.apache.commons:commons-compress:1.27.1")
    testImplementation("junit:junit:4.13.2")
}
