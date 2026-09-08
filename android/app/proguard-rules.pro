# ─── Flutter Core & Engine ───────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ─── Notifications & Alarms ───────────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin$* { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class androidx.work.** { *; }

# ─── SQLite & Database ────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# ─── JSON Models & Gson Reflection (Required for TypeToken) ───────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class * extends com.google.gson.reflect.TypeToken { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ─── Google Sign-In / GMS ─────────────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**

# ─── General Android ──────────────────────────────────────────────────────────
# Keep all Parcelable implementations (used by Android IPC).
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Keep Serializable classes intact.
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Suppress warnings for missing optional dependency classes.
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn com.google.android.play.core.**
