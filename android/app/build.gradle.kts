// ─── Plugins ─────────────────────────────────────────────────────────────────
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Flutter Gradle Plugin must be applied AFTER Android + Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google services plugin – processes google-services.json for Firebase.
    id("com.google.gms.google-services")
}

// ─── Android configuration ────────────────────────────────────────────────────
android {
    namespace = "com.example.nooktime"

    // Pinned explicitly – do NOT delegate to flutter.compileSdkVersion so the
    // build stays reproducible across Flutter SDK upgrades.
    // 36 required by: google_sign_in_android, shared_preferences_android,
    //   sqflite_android, androidx.credentials:1.6.0, androidx.core-ktx:1.15.0
    compileSdk = 36

    // NDK version is safe to forward from the Flutter SDK; it only affects
    // native (C/C++) plug-ins and is not a reproducibility concern.
    ndkVersion = flutter.ndkVersion

    // ─── Java / Kotlin toolchain ──────────────────────────────────────────────
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // ─── Default config ───────────────────────────────────────────────────────
    defaultConfig {
        applicationId = "com.example.nooktime"

        // minSdk comes from the Flutter SDK so it tracks Flutter's own minimum.
        // Override with a literal integer here only if your app needs a higher floor.
        minSdk = flutter.minSdkVersion
        // targetSdk controls runtime behaviour opt-ins; keep at 35 (Android 15).
        // Raise to 36 only after verifying Android 16 behaviour changes.
        targetSdk = 35

        // Version metadata delegated to Flutter so that --build-name /
        // --build-number CLI flags and CI pipelines work correctly.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ─── Build types ──────────────────────────────────────────────────────────
    buildTypes {
        debug {
            isDebuggable = true
            // Debug signing is applied automatically by AGP; no explicit config needed.
        }
        release {
            // Signed with debug keys so testers can install directly without
            // a custom keystore setup. Replace before publishing to Play Store.
            signingConfig = signingConfigs.getByName("debug")

            // R8 full-mode: shrink, obfuscate, and optimise class files.
            isMinifyEnabled = true

            // Strip unused resource files (drawables, layouts, strings, etc.)
            // Only effective when isMinifyEnabled = true.
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ─── Lint ─────────────────────────────────────────────────────────────────
    lint {
        // Prevents a single lint error from aborting the entire build.
        abortOnError = false
        // Skips expensive lint checks on release variants during development.
        checkReleaseBuilds = false
    }
}

// ─── Flutter source ───────────────────────────────────────────────────────────
flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase BoM – ensures all Firebase libraries use compatible versions.
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))

    // Firebase SDKs (versions managed by BoM – do not specify versions here).
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}

configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
    }
}
