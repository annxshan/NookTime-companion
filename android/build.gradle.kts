// ─── Root build.gradle.kts ────────────────────────────────────────────────────
// AGP and Kotlin plugins are declared with `apply false` in settings.gradle.kts
// and applied individually inside :app.  No plugins {} block is needed here.

// ─── Repository configuration (fallback for all subprojects) ─────────────────
// dependencyResolutionManagement in settings.gradle.kts uses PREFER_SETTINGS,
// so these repos act as a safety net for any edge case where a subproject is
// resolved before the settings-level repos have been applied.
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }
    }
}

// Force compatible androidx versions across all subprojects to prevent AGP 8.9.1 metadata check failures
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.core:core:1.15.0")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.activity:activity:1.9.3")
        }
    }
}

// ─── Build output redirection ─────────────────────────────────────────────────
val rootBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(rootBuildDir)

// :app → E:\Projects\nooktime\build\app  (Flutter standard output location)
project(":app").layout.buildDirectory.value(rootBuildDir.dir("app"))

// ─── compileSdk + namespace backfill for legacy Flutter plug-ins ───────────────
subprojects {
    afterEvaluate {
        // :app manages its own namespace and compileSdk – never touch it here.
        if (project.name == "app") return@afterEvaluate

        // Only act on projects that have applied an Android plugin.
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate

        try {
            val base = androidExt as com.android.build.gradle.BaseExtension

            // ── 1. compileSdk backfill ────────────────────────────────────────
            val currentSdk = base.compileSdkVersion
                ?.removePrefix("android-")
                ?.toIntOrNull() ?: 0

            if (currentSdk < 36) {
                base.compileSdkVersion(36)
                logger.info("[nooktime] :${project.name} compileSdk raised $currentSdk → 36")
            }

            // ── 2. Namespace injection ────────────────────────────────────────
            val getNs = runCatching {
                androidExt.javaClass.getMethod("getNamespace")
            }.getOrNull() ?: return@afterEvaluate

            val existingNs = getNs.invoke(androidExt) as? String
            if (existingNs.isNullOrBlank()) {
                val group = project.group.toString()
                    .ifBlank { "com.flutter.plugin" }
                    .replace(Regex("[^a-zA-Z0-9.]"), "_")
                val name = project.name
                    .replace(Regex("[^a-zA-Z0-9]"), "_")
                    .lowercase()
                val syntheticNs = "$group.$name"

                runCatching {
                    androidExt.javaClass
                        .getMethod("setNamespace", String::class.java)
                        .invoke(androidExt, syntheticNs)
                }.onSuccess {
                    logger.info("[nooktime] :${project.name} namespace → '$syntheticNs'")
                }.onFailure { e ->
                    logger.warn("[nooktime] :${project.name} namespace injection failed: ${e.message}")
                }
            }
        } catch (e: Exception) {
            logger.info("[nooktime] Skipping Android patch for :${project.name}: ${e.message}")
        }
    }
}

// ─── Evaluation order ─────────────────────────────────────────────────────────
subprojects {
    project.evaluationDependsOn(":app")
}

// ─── Clean task ───────────────────────────────────────────────────────────────
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
