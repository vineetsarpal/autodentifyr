# ProGuard rules for AutoDentifyr

# SnakeYAML relies on java.beans which is not available on Android
# These classes are not used at runtime on Android, so we can safely ignore the warnings.
-dontwarn java.beans.**
-dontwarn org.yaml.snakeyaml.**
