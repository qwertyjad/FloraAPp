# Keep TensorFlow Lite classes, especially for GPU delegation
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }

## Flutter wrapper
 -keep class io.flutter.app.** { *; }
 -keep class io.flutter.plugin.** { *; }
 -keep class io.flutter.util.** { *; }
 -keep class io.flutter.view.** { *; }
 -keep class io.flutter.** { *; }
 -keep class io.flutter.plugins.** { *; }
 -keep class com.google.firebase.** { *; }
 -dontwarn io.flutter.embedding.**
 -ignorewarnings