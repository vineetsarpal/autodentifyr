# ProGuard rules for AutoDentifyr

# Room creates WorkManager's generated database through reflection at app startup.
# R8 must retain its no-argument constructor, not just the class name.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

# SnakeYAML relies on java.beans which is not available on Android
# These classes are not used at runtime on Android, so we can safely ignore the warnings.
-dontwarn java.beans.**
-dontwarn org.yaml.snakeyaml.**
