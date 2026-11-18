package com.sudepi.app

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer
import java.util.Collections
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.sudepi.app/yolo26"
        private const val INPUT_SIZE = 640
        private const val CHANNEL_STRIDE = INPUT_SIZE * INPUT_SIZE
        private const val INV_255 = 1.0f / 255.0f
        private const val LETTERBOX_PAD_VAL = 114.0f / 255.0f
        private const val NUM_CANDIDATES = 300
        private const val CANDIDATE_STRIDE = 6
        private const val NUM_CLASSES = 7

        // Tuning Geometry, Soft Center-Gravity & Proximity Priority
        private const val MIN_BOX_SIDE = 76.0f
        private const val MIN_BOX_AREA = 10000.0f
        private const val EDGE_MARGIN = 28.0f
        private const val CENTER_COORD = 320.0f
        private const val MAX_CENTER_DIST = 452.55f
        private const val REF_BOX_AREA = 140000.0f

        // Minimum candidate score to detect presence of a folded/partial bill for voice guidance
        private const val CANDIDATE_PRESENCE_FLOOR = 0.35f

        // 3-Tier Confidence Thresholds (Standar Keyakinan Berjenjang):
        // - Tier 1 (Kontras Tinggi & Nominal Besar: Rp20.000 [4], Rp50.000 [5], Rp100.000 [6]) -> >= 86%
        // - Tier 2 (Kontras Menengah: Rp1.000 [0], Rp5.000 [2], Rp10.000 [3]) -> >= 80%
        // - Tier 3 (Warna Netral: Rp2.000 [1]) -> >= 74%
        private const val TIER_1_HIGH_CONTRAST_CONF = 0.86f
        private const val TIER_2_MID_CONTRAST_CONF = 0.80f
        private const val TIER_3_NEUTRAL_RP2K_CONF = 0.74f

        private fun getRequiredClassConfidence(classId: Int): Float {
            return when (classId) {
                4, 5, 6 -> TIER_1_HIGH_CONTRAST_CONF
                0, 2, 3 -> TIER_2_MID_CONTRAST_CONF
                1 -> TIER_3_NEUTRAL_RP2K_CONF
                else -> TIER_1_HIGH_CONTRAST_CONF
            }
        }
    }

    private val inferenceExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val isBusy = AtomicBoolean(false)

    private var ortEnv: OrtEnvironment? = null
    private var ortSession: OrtSession? = null
    private var inputName: String = "images"

    // Pre-allocated NCHW float buffer [1, 3, 640, 640] to avoid per-frame GC allocations
    private val inputTensorArray = FloatArray(3 * CHANNEL_STRIDE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initModel" -> handleInitModel(call, result)
                    "analyzeFrame" -> handleAnalyzeFrame(call, result)
                    "vibratePattern" -> {
                        val pattern = call.argument<List<Int>>("pattern") ?: listOf(0, 40)
                        triggerVibration(pattern.map { it.toLong() }.toLongArray())
                        result.success(true)
                    }
                    "disposeModel" -> {
                        closeOrtResources()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleInitModel(call: MethodCall, result: MethodChannel.Result) {
        val assetPath = call.argument<String>("assetPath")
            ?: "assets/models/sudepi_yolo26n_640.onnx"

        inferenceExecutor.execute {
            try {
                val lookupKey = FlutterInjector.instance()
                    .flutterLoader()
                    .getLookupKeyForAsset(assetPath)

                val modelFile = File(filesDir, "sudepi_yolo26n_640.onnx")
                assets.open(lookupKey).use { inputStream ->
                    FileOutputStream(modelFile).use { outputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }

                val env = OrtEnvironment.getEnvironment()
                val sessionOptions = OrtSession.SessionOptions().apply {
                    setIntraOpNumThreads(4)
                    setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                }

                val session = env.createSession(modelFile.absolutePath, sessionOptions)
                val resolvedInputName = if (session.inputNames.isNotEmpty()) {
                    session.inputNames.iterator().next()
                } else {
                    "images"
                }

                ortEnv = env
                ortSession = session
                inputName = resolvedInputName

                runOnUiThread {
                    result.success(
                        mapOf(
                            "loaded" to true,
                            "modelPath" to modelFile.absolutePath,
                            "inputName" to resolvedInputName
                        )
                    )
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.success(
                        mapOf(
                            "loaded" to false,
                            "error" to (e.message ?: "Failed to load ONNX model")
                        )
                    )
                }
            }
        }
    }

    private fun handleAnalyzeFrame(call: MethodCall, result: MethodChannel.Result) {
        if (!isBusy.compareAndSet(false, true)) {
            result.success(mapOf("skipped" to true))
            return
        }

        val yBytes = call.argument<ByteArray>("yBytes")
        val uBytes = call.argument<ByteArray>("uBytes")
        val vBytes = call.argument<ByteArray>("vBytes")
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        val yRowStride = call.argument<Int>("yRowStride") ?: width
        val uvRowStride = call.argument<Int>("uvRowStride") ?: (width / 2)
        val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
        val sensorOrientation = call.argument<Int>("sensorOrientation") ?: 90
        val confThreshold = (call.argument<Double>("confThreshold") ?: 0.25).toFloat()

        if (yBytes == null || uBytes == null || vBytes == null || width <= 0 || height <= 0) {
            isBusy.set(false)
            result.error("INVALID_FRAME", "Frame plane data is incomplete", null)
            return
        }

        inferenceExecutor.execute {
            try {
                val startMs = SystemClock.elapsedRealtime()

                // 1. Compute average luminance (Y-plane) for One-Way Auto-ON Torch Latch
                val meanLuminance = calculateMeanLuminance(yBytes, width, height, yRowStride)

                val session = ortSession
                val env = ortEnv
                if (session == null || env == null) {
                    val elapsed = SystemClock.elapsedRealtime() - startMs
                    isBusy.set(false)
                    runOnUiThread {
                        result.success(
                            mapOf(
                                "skipped" to false,
                                "modelLoaded" to false,
                                "meanLuminance" to meanLuminance,
                                "inferenceTimeMs" to elapsed,
                                "detected" to false,
                                "classId" to -1,
                                "confidence" to 0.0
                            )
                        )
                    }
                    return@execute
                }

                // 2. Convert YUV_420_888 + Rotate (sensorOrientation) + Letterbox 640x640 into NCHW FloatArray
                preprocessYuvToLetterboxNchw(
                    yBytes = yBytes,
                    uBytes = uBytes,
                    vBytes = vBytes,
                    srcW = width,
                    srcH = height,
                    yRowStride = yRowStride,
                    uvRowStride = uvRowStride,
                    uvPixelStride = uvPixelStride,
                    sensorOrientation = sensorOrientation,
                    outArray = inputTensorArray
                )

                // 3. Run YOLO26n ONNX Inference -> Supports both [1, 11, 8400] (4 box + 7 classes) and [1, 300, 6]
                var bestClassId = -1
                var bestScore = 0.0f
                var bestPriority = 0.0f
                var bestX1 = 0.0f
                var bestY1 = 0.0f
                var bestX2 = 0.0f
                var bestY2 = 0.0f

                val classMaxRawScore = FloatArray(NUM_CLASSES)
                val classBestPriority = FloatArray(NUM_CLASSES)
                val classBestX1 = FloatArray(NUM_CLASSES)
                val classBestY1 = FloatArray(NUM_CLASSES)
                val classBestX2 = FloatArray(NUM_CLASSES)
                val classBestY2 = FloatArray(NUM_CLASSES)

                val floatBuffer = FloatBuffer.wrap(inputTensorArray)
                val inputShape = longArrayOf(1L, 3L, INPUT_SIZE.toLong(), INPUT_SIZE.toLong())
                val maxEdgeCoord = INPUT_SIZE.toFloat() - EDGE_MARGIN

                OnnxTensor.createTensor(env, floatBuffer, inputShape).use { inputTensor ->
                    session.run(Collections.singletonMap(inputName, inputTensor)).use { ortResult ->
                        val outputTensor = ortResult.get(0) as OnnxTensor
                        val outBuf = outputTensor.floatBuffer
                        val outShape = outputTensor.info.shape
                        val totalFloats = outBuf.remaining()

                        if (outShape.size == 3 &&
                            outShape[1].toInt() >= (4 + NUM_CLASSES) &&
                            outShape[2].toInt() > CANDIDATE_STRIDE
                        ) {
                            // Format [1, 11, 8400]: rows 0..3 = [cx, cy, w, h], rows 4..10 = 7 class scores
                            val numAnchors = outShape[2].toInt()
                            val wRowOffset = 2 * numAnchors
                            val hRowOffset = 3 * numAnchors

                            for (c in 0 until NUM_CLASSES) {
                                val clsRowOffset = (4 + c) * numAnchors
                                if (clsRowOffset + numAnchors > totalFloats) break

                                for (a in 0 until numAnchors) {
                                    val score = outBuf.get(clsRowOffset + a)
                                    // Record classMaxRawScore across all valid-geometry anchors down to 0.02f
                                    // so secondary Rp2.000 activations (0.07..0.24) on folded bills are preserved.
                                    if (score >= 0.02f) {
                                        val bw = outBuf.get(wRowOffset + a)
                                        val bh = outBuf.get(hRowOffset + a)
                                        val area = bw * bh
                                        if (bw >= MIN_BOX_SIDE && bh >= MIN_BOX_SIDE && area >= MIN_BOX_AREA) {
                                            val cx = outBuf.get(a)
                                            val cy = outBuf.get(numAnchors + a)
                                            // Edge-Margin Cutoff: ignore stray objects at extreme 4.4% frame border
                                            if (cx in EDGE_MARGIN..maxEdgeCoord && cy in EDGE_MARGIN..maxEdgeCoord) {
                                                if (score > classMaxRawScore[c]) {
                                                    classMaxRawScore[c] = score
                                                }
                                                val prio = computePriorityScore(score, cx, cy, area)
                                                if (prio > classBestPriority[c]) {
                                                    classBestPriority[c] = prio
                                                    classBestX1[c] = (cx - 0.5f * bw).coerceIn(0.0f, INPUT_SIZE.toFloat())
                                                    classBestY1[c] = (cy - 0.5f * bh).coerceIn(0.0f, INPUT_SIZE.toFloat())
                                                    classBestX2[c] = (cx + 0.5f * bw).coerceIn(0.0f, INPUT_SIZE.toFloat())
                                                    classBestY2[c] = (cy + 0.5f * bh).coerceIn(0.0f, INPUT_SIZE.toFloat())
                                                }
                                                if (score >= CANDIDATE_PRESENCE_FLOOR && prio > bestPriority) {
                                                    bestPriority = prio
                                                    bestScore = score
                                                    bestClassId = c
                                                    bestX1 = classBestX1[c]
                                                    bestY1 = classBestY1[c]
                                                    bestX2 = classBestX2[c]
                                                    bestY2 = classBestY2[c]
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // Format [1, 300, 6]: [x1, y1, x2, y2, score, class_id]
                            val candidates = min(NUM_CANDIDATES, totalFloats / CANDIDATE_STRIDE)
                            for (i in 0 until candidates) {
                                val base = i * CANDIDATE_STRIDE
                                val score = outBuf.get(base + 4)
                                if (score >= 0.02f) {
                                    val cls = outBuf.get(base + 5).toInt()
                                    if (cls in 0 until NUM_CLASSES) {
                                        val x1 = outBuf.get(base)
                                        val y1 = outBuf.get(base + 1)
                                        val x2 = outBuf.get(base + 2)
                                        val y2 = outBuf.get(base + 3)
                                        val bw = max(0.0f, x2 - x1)
                                        val bh = max(0.0f, y2 - y1)
                                        val area = bw * bh
                                        val cx = x1 + 0.5f * bw
                                        val cy = y1 + 0.5f * bh
                                        if (bw >= MIN_BOX_SIDE && bh >= MIN_BOX_SIDE && area >= MIN_BOX_AREA &&
                                            cx in EDGE_MARGIN..maxEdgeCoord && cy in EDGE_MARGIN..maxEdgeCoord
                                        ) {
                                            if (score > classMaxRawScore[cls]) {
                                                classMaxRawScore[cls] = score
                                            }
                                            val prio = computePriorityScore(score, cx, cy, area)
                                            if (prio > classBestPriority[cls]) {
                                                classBestPriority[cls] = prio
                                                classBestX1[cls] = x1
                                                classBestY1[cls] = y1
                                                classBestX2[cls] = x2
                                                classBestY2[cls] = y2
                                            }
                                            if (score >= CANDIDATE_PRESENCE_FLOOR && prio > bestPriority) {
                                                bestPriority = prio
                                                bestScore = score
                                                bestClassId = cls
                                                bestX1 = x1
                                                bestY1 = y1
                                                bestX2 = x2
                                                bestY2 = y2
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 4. Sistem Veto Lipatan & Ambang Keyakinan Berjenjang 3 Tingkat (3-Tier Confidence Gate):
                // - Tidak pernah memaksa kelas lain menjadi Rp2.000 dengan akurasi buatan (menghilangkan bug 60%).
                // - Jika terdapat sinyal kompetisi Rp2.000 pada uang terlipat (rp2kRaw >= 0.025f, sedangkan uang
                //   asli non-Rp2.000 selalu memiliki rp2kRaw <= 0.001f), hanya luluskan sebagai Rp2.000 apabila
                //   rp2kRaw sendiri mencapai ambang Tier 3 (>= 0.74f). Jika belum, VETO deteksi dan minta uang direntangkan.
                var needsUnfoldPrompt = false
                if (bestClassId in 0 until NUM_CLASSES) {
                    val rp2kRaw = classMaxRawScore[1]
                    val (meanSaturation, meanBlueExcess, _) = measureBoxChromaMetrics(
                        inputTensorArray,
                        bestX1,
                        bestY1,
                        bestX2,
                        bestY2
                    )

                    if (bestClassId != 1 && rp2kRaw >= 0.025f) {
                        if (rp2kRaw >= TIER_3_NEUTRAL_RP2K_CONF &&
                            (meanSaturation < 0.30f || meanBlueExcess < 36.0f)
                        ) {
                            bestClassId = 1
                            bestScore = rp2kRaw
                            if (classBestPriority[1] > 0.0f) {
                                bestX1 = classBestX1[1]
                                bestY1 = classBestY1[1]
                                bestX2 = classBestX2[1]
                                bestY2 = classBestY2[1]
                            }
                        } else {
                            // Uang Rp2.000 terlipat ekstrem (skor Rp2.000 masih di bawah 74%): Veto & minta direntangkan
                            bestClassId = -1
                            needsUnfoldPrompt = true
                        }
                    } else if (bestClassId == 5 && meanSaturation < 0.16f && meanBlueExcess < 16.0f) {
                        // Veto bercak abu-abu pucat yang dikira Rp50.000
                        bestClassId = -1
                        needsUnfoldPrompt = true
                    }

                    if (bestClassId in 0 until NUM_CLASSES) {
                        val requiredConf = getRequiredClassConfidence(bestClassId)
                        if (bestScore < requiredConf) {
                            // Kandidat uang terdeteksi namun belum memenuhi standar keyakinan ketat (perlu direntangkan)
                            bestClassId = -1
                            needsUnfoldPrompt = true
                        }
                    }
                }

                val isLockedDetection = bestClassId in 0 until NUM_CLASSES && bestScore >= confThreshold
                val maxRawCandidateScore = classMaxRawScore.maxOrNull() ?: 0.0f
                val hasBillObject = maxRawCandidateScore >= 0.18f || isLockedDetection || needsUnfoldPrompt
                val elapsedMs = SystemClock.elapsedRealtime() - startMs
                val responseMap = mapOf(
                    "skipped" to false,
                    "modelLoaded" to true,
                    "meanLuminance" to meanLuminance,
                    "inferenceTimeMs" to elapsedMs,
                    "detected" to isLockedDetection,
                    "hasBillObject" to hasBillObject,
                    "needsUnfoldPrompt" to needsUnfoldPrompt,
                    "classId" to bestClassId,
                    "confidence" to bestScore.toDouble(),
                    "box" to listOf(
                        bestX1.toDouble(),
                        bestY1.toDouble(),
                        bestX2.toDouble(),
                        bestY2.toDouble()
                    )
                )

                isBusy.set(false)
                runOnUiThread {
                    result.success(responseMap)
                }
            } catch (e: Exception) {
                isBusy.set(false)
                runOnUiThread {
                    result.error("INFERENCE_ERROR", e.message ?: "Error during ONNX inference", null)
                }
            }
        }
    }

    /**
     * Soft Center-Gravity & Size Proximity Priority Score:
     * - CenterWeight (0.65 .. 1.00): favors bills closer to the camera center (320, 320)
     * - SizeWeight   (0.85 .. 1.00): favors bills held closer to the lens (larger area)
     */
    private fun computePriorityScore(
        rawScore: Float,
        cx: Float,
        cy: Float,
        area: Float
    ): Float {
        val dx = cx - CENTER_COORD
        val dy = cy - CENTER_COORD
        val distNorm = (sqrt(dx * dx + dy * dy) / MAX_CENTER_DIST).coerceIn(0.0f, 1.0f)
        val centerWeight = 1.0f - 0.35f * distNorm
        val areaNorm = (area / REF_BOX_AREA).coerceIn(0.0f, 1.0f)
        val sizeWeight = 0.85f + 0.15f * areaNorm
        return rawScore * centerWeight * sizeWeight
    }

    /**
     * Computes (meanSaturation, meanBlueExcess, intrinsicChromaSpread) inside the inner 70%
     * of the detected bounding box to distinguish true pigmented banknotes from achromatic Rp2.000.
     */
    private fun measureBoxChromaMetrics(
        nchwArray: FloatArray,
        x1: Float,
        y1: Float,
        x2: Float,
        y2: Float
    ): Triple<Float, Float, Float> {
        val bw = max(1.0f, x2 - x1)
        val bh = max(1.0f, y2 - y1)
        val startX = (x1 + 0.15f * bw).toInt().coerceIn(0, INPUT_SIZE - 1)
        val endX = (x2 - 0.15f * bw).toInt().coerceIn(startX, INPUT_SIZE - 1)
        val startY = (y1 + 0.15f * bh).toInt().coerceIn(0, INPUT_SIZE - 1)
        val endY = (y2 - 0.15f * bh).toInt().coerceIn(startY, INPUT_SIZE - 1)

        var satSum = 0.0f
        var blueExcessSum = 0.0f
        var sumR = 0.0f
        var sumG = 0.0f
        var sumB = 0.0f
        var count = 0
        val step = 4

        var py = startY
        while (py <= endY) {
            val rowOffset = py * INPUT_SIZE
            var px = startX
            while (px <= endX) {
                val idx = rowOffset + px
                val r = nchwArray[idx]
                val g = nchwArray[CHANNEL_STRIDE + idx]
                val b = nchwArray[2 * CHANNEL_STRIDE + idx]

                val r255 = r * 255.0f
                val g255 = g * 255.0f
                val b255 = b * 255.0f

                val maxRgb = max(r255, max(g255, b255))
                val minRgb = min(r255, min(g255, b255))
                val sat = if (maxRgb > 10.0f) (maxRgb - minRgb) / maxRgb else 0.0f

                satSum += sat
                blueExcessSum += (b255 - r255)
                sumR += r
                sumG += g
                sumB += b
                count++
                px += step
            }
            py += step
        }

        if (count == 0) return Triple(0.0f, 0.0f, 1.0f)
        val invCount = 1.0f / count.toFloat()
        val meanR = sumR * invCount + 1e-5f
        val meanG = sumG * invCount + 1e-5f
        val meanB = sumB * invCount + 1e-5f
        val gray = (meanR + meanG + meanB) * 0.3333333f
        val wbR = gray / meanR
        val wbG = gray / meanG
        val wbB = gray / meanB

        var spreadSum = 0.0f
        py = startY
        while (py <= endY) {
            val rowOffset = py * INPUT_SIZE
            var px = startX
            while (px <= endX) {
                val idx = rowOffset + px
                val nr = nchwArray[idx] * wbR
                val ng = nchwArray[CHANNEL_STRIDE + idx] * wbG
                val nb = nchwArray[2 * CHANNEL_STRIDE + idx] * wbB
                spreadSum += abs(nr - ng) + abs(ng - nb) + abs(nb - nr)
                px += step
            }
            py += step
        }

        return Triple(
            satSum * invCount,
            blueExcessSum * invCount,
            spreadSum * invCount
        )
    }

    /**
     * Normalisasi Pencahayaan Adaptif Dua Jalur (Dual-Pathway Adaptive Illuminant Normalization):
     * - Mengukur Sebaran Kromatik Intrinsik (intrinsicChromaSpread) pada area tengah frame.
     * - Jalur 1 (Jalur Netralisasi Akromatik, intrinsicChromaSpread < ACHROMATIC_SPREAD_THRESHOLD):
     *   Menarik penuh keseimbangan kanal ke profil abu-abu asli Rp2.000 [0.97, 1.00, 1.03] + desaturasi 40%.
     * - Jalur 2 (Jalur Penyeimbang Kromatik Teredam, intrinsicChromaSpread >= ACHROMATIC_SPREAD_THRESHOLD):
     *   Menetralkan bias lampu ruangan secara teredam (pow 0.75, batas [0.85, 1.18]) agar pigmen warna tetap kuat.
     */
    private fun applyDualPathwayWhiteBalance(
        outArray: FloatArray,
        padX: Int,
        padY: Int,
        newW: Int,
        newH: Int
    ) {
        val roiX1 = (padX + (newW * 0.15f).toInt()).coerceIn(0, INPUT_SIZE - 1)
        val roiX2 = (padX + (newW * 0.85f).toInt()).coerceIn(roiX1, INPUT_SIZE - 1)
        val roiY1 = (padY + (newH * 0.15f).toInt()).coerceIn(0, INPUT_SIZE - 1)
        val roiY2 = (padY + (newH * 0.85f).toInt()).coerceIn(roiY1, INPUT_SIZE - 1)

        var sumR = 0.0f
        var sumG = 0.0f
        var sumB = 0.0f
        var midCount = 0
        val step = 4

        var py = roiY1
        while (py <= roiY2) {
            val rowOffset = py * INPUT_SIZE
            var px = roiX1
            while (px <= roiX2) {
                val idx = rowOffset + px
                val r = outArray[idx]
                val g = outArray[CHANNEL_STRIDE + idx]
                val b = outArray[2 * CHANNEL_STRIDE + idx]
                val lum = (r + g + b) * 0.3333333f
                if (lum in 0.10f..0.88f) {
                    sumR += r
                    sumG += g
                    sumB += b
                    midCount++
                }
                px += step
            }
            py += step
        }

        if (midCount < 50) return

        val invMid = 1.0f / midCount.toFloat()
        val meanR = sumR * invMid + 1e-5f
        val meanG = sumG * invMid + 1e-5f
        val meanB = sumB * invMid + 1e-5f
        val grayMean = (meanR + meanG + meanB) * 0.3333333f

        val wbR = grayMean / meanR
        val wbG = grayMean / meanG
        val wbB = grayMean / meanB

        // Selective Illuminant Gate: only apply gentle damped white-balance when there is a
        // strong room light color cast (max channel deviation >= 9.0%). Never desaturate pixels,
        // so colored banknotes (e.g., purple Rp10.000 against a cream wall) keep their full pigment.
        val maxChannelDev = max(abs(wbR - 1.0f), max(abs(wbG - 1.0f), abs(wbB - 1.0f)))
        if (maxChannelDev < 0.09f) return

        val endY = (padY + newH).coerceIn(0, INPUT_SIZE)
        val endX = (padX + newW).coerceIn(0, INPUT_SIZE)

        val gainR = wbR.toDouble().pow(0.65).toFloat().coerceIn(0.88f, 1.12f)
        val gainG = wbG.toDouble().pow(0.65).toFloat().coerceIn(0.88f, 1.12f)
        val gainB = wbB.toDouble().pow(0.65).toFloat().coerceIn(0.88f, 1.12f)

        if (abs(gainR - 1.0f) > 0.015f || abs(gainG - 1.0f) > 0.015f || abs(gainB - 1.0f) > 0.015f) {
            for (dy in padY until endY) {
                val rowBase = dy * INPUT_SIZE
                for (dx in padX until endX) {
                    val idx = rowBase + dx
                    outArray[idx] = (outArray[idx] * gainR).coerceIn(0.0f, 1.0f)
                    outArray[CHANNEL_STRIDE + idx] = (outArray[CHANNEL_STRIDE + idx] * gainG).coerceIn(0.0f, 1.0f)
                    outArray[2 * CHANNEL_STRIDE + idx] = (outArray[2 * CHANNEL_STRIDE + idx] * gainB).coerceIn(0.0f, 1.0f)
                }
            }
        }
    }

    private fun calculateMeanLuminance(
        yBytes: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int
    ): Double {
        var sum = 0L
        var count = 0L
        val step = 4
        var row = 0
        while (row < height) {
            val rowOffset = row * yRowStride
            var col = 0
            while (col < width) {
                val idx = rowOffset + col
                if (idx < yBytes.size) {
                    sum += (yBytes[idx].toInt() and 0xFF)
                    count++
                }
                col += step
            }
            row += step
        }
        return if (count > 0L) sum.toDouble() / count.toDouble() else 128.0
    }

    private fun preprocessYuvToLetterboxNchw(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        srcW: Int,
        srcH: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
        sensorOrientation: Int,
        outArray: FloatArray
    ) {
        // Fill with letterbox gray (114 / 255)
        outArray.fill(LETTERBOX_PAD_VAL)

        val normOrientation = ((sensorOrientation % 360) + 360) % 360
        val rotW = if (normOrientation == 90 || normOrientation == 270) srcH else srcW
        val rotH = if (normOrientation == 90 || normOrientation == 270) srcW else srcH

        val scale = min(
            INPUT_SIZE.toFloat() / rotW.toFloat(),
            INPUT_SIZE.toFloat() / rotH.toFloat()
        )
        val newW = (rotW * scale).toInt().coerceIn(1, INPUT_SIZE)
        val newH = (rotH * scale).toInt().coerceIn(1, INPUT_SIZE)
        val padX = (INPUT_SIZE - newW) / 2
        val padY = (INPUT_SIZE - newH) / 2
        val invScale = 1.0f / scale

        val ySize = yBytes.size
        val uSize = uBytes.size
        val vSize = vBytes.size

        for (dy in padY until (padY + newH)) {
            val ry = ((dy - padY) * invScale).toInt().coerceIn(0, rotH - 1)
            val rowBase = dy * INPUT_SIZE

            for (dx in padX until (padX + newW)) {
                val rx = ((dx - padX) * invScale).toInt().coerceIn(0, rotW - 1)

                val sx: Int
                val sy: Int
                when (normOrientation) {
                    90 -> {
                        sx = ry
                        sy = srcH - 1 - rx
                    }
                    270 -> {
                        sx = srcW - 1 - ry
                        sy = rx
                    }
                    180 -> {
                        sx = srcW - 1 - rx
                        sy = srcH - 1 - ry
                    }
                    else -> {
                        sx = rx
                        sy = ry
                    }
                }

                val yIdx = (sy * yRowStride + sx).coerceIn(0, ySize - 1)
                val uvIdx = ((sy shr 1) * uvRowStride + (sx shr 1) * uvPixelStride)

                val yVal = yBytes[yIdx].toInt() and 0xFF
                val uVal = (uBytes[uvIdx.coerceIn(0, uSize - 1)].toInt() and 0xFF) - 128
                val vVal = (vBytes[uvIdx.coerceIn(0, vSize - 1)].toInt() and 0xFF) - 128

                val r = (yVal + ((1436 * vVal) shr 10)).coerceIn(0, 255)
                val g = (yVal - ((352 * uVal + 731 * vVal) shr 10)).coerceIn(0, 255)
                val b = (yVal + ((1815 * uVal) shr 10)).coerceIn(0, 255)

                val pixelIdx = rowBase + dx
                outArray[pixelIdx] = r * INV_255
                outArray[CHANNEL_STRIDE + pixelIdx] = g * INV_255
                outArray[2 * CHANNEL_STRIDE + pixelIdx] = b * INV_255
            }
        }

        // Apply Dual-Pathway Adaptive Illuminant Normalization before ONNX inference
        applyDualPathwayWhiteBalance(outArray, padX, padY, newW, newH)
    }

    private fun triggerVibration(pattern: LongArray) {
        try {
            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                manager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(pattern, -1)
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun closeOrtResources() {
        try {
            ortSession?.close()
            ortSession = null
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        closeOrtResources()
        inferenceExecutor.shutdownNow()
        super.onDestroy()
    }
}
