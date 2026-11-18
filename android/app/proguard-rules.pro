# Keep all ONNX Runtime classes and members from being stripped or obfuscated by R8.
# Native JNI (libonnxruntime4j_jni.so) looks up ai.onnxruntime.TensorInfo, OnnxTensor,
# OrtSession$Result, etc. dynamically via FindClass / GetMethodID during OrtSession.run().
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Preserve all native method signatures
-keepclasseswithmembernames class * {
    native <methods>;
}
