// ─── Plugin Management ────────────────────────────────────────────────────────
pluginManagement {
    // Resolve the Flutter SDK path that `flutter pub get` writes into local.properties.
    val flutterSdkPath: String = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        props.getProperty("flutter.sdk")
            ?: error("flutter.sdk not set in local.properties – run `flutter pub get` first.")
    }

    // Register Flutter Gradle tooling as a composite build so that the
    // dev.flutter.* plugin IDs resolve without a separate Maven publication.
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Plugin artifact repositories (used only to resolve Gradle plugins, not
    // application runtime dependencies).
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// ─── Dependency Resolution Management ────────────────────────────────────────
// All repositories that *any* subproject might need are declared here at the
// settings level.  repositoriesMode = PREFER_SETTINGS means that if a plugin's
// own build.gradle also declares repos, those declarations are silently ignored
// in favour of this list – no build failure.
//
// IMPORTANT: Every repo that Flutter plug-ins might declare must be mirrored
// here; otherwise PREFER_SETTINGS will silently skip it and resolution fails.
@Suppress("UnstableApiUsage")
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)

    repositories {
        // Core Android + Kotlin artifacts
        google()
        mavenCentral()

        // Flutter engine binaries and AAR-published Flutter plug-ins.
        // Required by flutter_tools/gradle and packages such as google_sign_in_android.
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }

        // Fallback for community packages that publish only to JitPack.
        maven { url = uri("https://jitpack.io") }
    }
}

// ─── Plugins ─────────────────────────────────────────────────────────────────
plugins {
    // Flutter tooling loader – version string is required but the actual
    // implementation comes from the composite build declared above.
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // Android Gradle Plugin 8.6.0:
    //   • Minimum required by Flutter's build validator (>= 8.6.0).
    //   • Compatible with Gradle 8.9 (AGP 8.6 requires Gradle >= 8.7).
    id("com.android.application") version "8.6.0" apply false

    // Kotlin 2.1.21:
    //   • Minimum required by Flutter's build validator (>= 2.1.0).
    //   • Latest stable in the 2.1.x series; compatible with AGP 8.6.0.
    id("org.jetbrains.kotlin.android") version "2.1.21" apply false

    // Google services plugin – required to process google-services.json
    // and configure Firebase SDKs (Firestore, Auth, Analytics).
    id("com.google.gms.google-services") version "4.5.0" apply false
}

// ─── Module graph ─────────────────────────────────────────────────────────────
include(":app")
