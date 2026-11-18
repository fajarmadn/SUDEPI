<p align="center">
  <img src="./docs/images/sudepi-banner.png" alt="SUDEPI — Suara Deteksi Rupiah" width="560" />
</p>

<p align="center">
  <strong>Asisten Deteksi Uang Kertas Rupiah & Verifikasi Kembalian Berbasis Visi Komputer 100% Luring untuk Tunanetra</strong>
</p>

<p align="center">
  <a href="https://github.com/fajarmadn/SUDEPI/releases/latest">
    <img src="https://img.shields.io/github/v/release/fajarmadn/SUDEPI?label=Rilis%20Terbaru&color=1967D2" alt="GitHub Release" />
  </a>
  <img src="https://img.shields.io/badge/Android-7.0%2B%20(API%2024%2B)-137333" alt="Android 7.0+" />
  <img src="https://img.shields.io/badge/Flutter-3.44-1967D2" alt="Flutter" />
  <img src="https://img.shields.io/badge/Model-YOLO26n%20ONNX-202124" alt="YOLO26n ONNX" />
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-5F6368" alt="MIT License" />
  </a>
</p>

---

## Tentang SUDEPI

**SUDEPI (Suara Deteksi Rupiah)** adalah aplikasi asisten mandiri berbasis Android yang dirancang khusus dengan pendekatan ***100% Blind-First, Zero-Button UX*** untuk membantu penyandang tunanetra dan *low vision* mengenali **7 pecahan uang kertas Rupiah Tahun Emisi 2022 (`Rp1.000` s.d. `Rp100.000`)** serta memverifikasi uang kembalian belanja secara bertahap.

Seluruh pemrosesan kecerdasan buatan (`YOLO26n` + *ONNX Runtime*), panduan suara (*Text-to-Speech* Bahasa Indonesia), dan umpan balik getaran (*Haptic Feedback*) berjalan **100% luring (*offline*) di perangkat** tanpa memerlukan koneksi internet, tanpa iklan, dan tanpa mengirim foto kamera maupun rekaman suara ke server mana pun.

---

## Unduh Aplikasi Android (APK Siap Pakai)

Pengguna umum dapat langsung mengunduh berkas instalasi `.apk` dari halaman [**GitHub Releases**](https://github.com/fajarmadn/SUDEPI/releases/latest) sesuai jenis perangkat Android:

| Paket Instalasi | Perangkat yang Didukung | Ukuran | Tautan Unduh Langsung |
| :--- | :--- | :---: | :---: |
| **`SUDEPI-arm64-v8a.apk`** *(Direkomendasikan)* | Mayoritas HP Android modern **64-bit** (keluaran ~2018 ke atas) | ~45,5 MB | [**Unduh 64-bit (.apk)**](https://github.com/fajarmadn/SUDEPI/releases/latest/download/SUDEPI-arm64-v8a.apk) |
| **`SUDEPI-armeabi-v7a.apk`** | HP Android lawas / kelas entri **32-bit** (minimal Android 7.0 Nougat) | ~37,8 MB | [**Unduh 32-bit (.apk)**](https://github.com/fajarmadn/SUDEPI/releases/latest/download/SUDEPI-armeabi-v7a.apk) |

> **Catatan Instalasi Pertama Kali:**
> 1. Buka berkas `.apk` yang selesai diunduh pada ponsel Android Anda (izinkan opsi *"Instal aplikasi yang tidak dikenal"* dari peramban/manajer berkas bila diminta).
> 2. Saat pertama kali dibuka, berikan izin **Kamera** (untuk memindai uang) dan **Mikrofon** (untuk menyebutkan nominal belanja).
> 3. Pastikan mesin suara Bahasa Indonesia (*Speech Recognition & Synthesis from Google*) aktif pada pengaturan *Text-to-Speech* ponsel agar panduan suara terdengar alami.

---

## Panduan Penggunaan Tanpa Tombol (*Zero-Button Gesture UX*)

SUDEPI mengadopsi interaksi kanvas layar penuh sehingga pengguna tunanetra tidak perlu mencari tombol kecil di layar. Seluruh alur terbagi ke dalam **4 layar berurutan**:

| Layar | Ketuk 1× | Ketuk 2× | Tahan Layar (*Hold*) | Usap ke Kiri (Maju) | Usap ke Kanan (Mundur) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Mode Siaga** *(Deteksi 1 Lembar)* | Ulangi panduan / bacakan nominal terdeteksi | Nyalakan / matikan senter kamera | — | Mulai transaksi belanja (ke Layar 2) | — |
| **2. Total Belanja** *(Input Suara / Angka)* | Bacakan status nominal belanja | Buka / tutup papan angka cadangan | **Push-to-Talk:** tahan & sebutkan harga belanja, lalu lepas | Lanjut ke Uang Diberikan (ke Layar 3) | Kembali ke Mode Siaga |
| **3. Uang Diberikan** *(Input Suara / Angka)* | Bacakan uang dibayar & hitung kembalian | Buka / tutup papan angka cadangan | **Push-to-Talk:** tahan & sebutkan uang yang dibayarkan | Mulai pindai uang kembalian (jika ada kembalian) | Kembali ke Total Belanja |
| **4. Cek Kembalian** *(Scan Sekuensial)* | Bacakan target kembalian, terkumpul, & sisa | Nyalakan / matikan senter kamera | Ulangi / *reset* hitungan kembalian ke `Rp 0` | Selesai transaksi (kembali ke Mode Siaga) | Kembali ke Uang Diberikan |

### Pola Getaran (*Tactile Haptic Signature*) per Pecahan
Selain menyebutkan nominal melalui suara, SUDEPI menghasilkan pola getaran unik untuk membantu konfirmasi taktil di lingkungan bising:
- **`Rp1.000` / `Rp2.000` / `Rp5.000`:** 1, 2, dan 3 getaran pendek (`55 ms`).
- **`Rp10.000` / `Rp20.000` / `Rp50.000`:** 1, 2, dan 3 getaran sedang (`150 ms`).
- **`Rp100.000`:** 1 getaran panjang tegas (`420 ms`).

---

## Keunggulan Teknis & Spesifikasi Model AI

1. **Detektor `YOLO26n` *End-to-End NMS-Free* (`9,49 MB` FP32 ONNX):**
   - Dilatih secara seragam pada **88.387 citra uang kertas Rupiah** terkurasi bebas kebocoran data (*0% group data leakage*: `81.407 train` / `3.490 valid` / `3.490 test`).
   - Mencapai akurasi uji ***test set* `mAP@50 = 99,28%`** (`Precision = 98,94%`, `Recall = 98,53%`, `mAP@50:95 = 93,86%`) dengan latensi inferensi rata-rata CPU **`24,96 ms/citra`** dan keluaran tensor langsung `[1, 300, 6]` tanpa beban pascaproses *Non-Maximum Suppression* (NMS).
2. **Gerbang Kepercayaan 3-Tingkat (*3-Tier Confidence Gate*) & Proteksi Uang Terlipat:**
   - Menerapkan ambang kepercayaan adaptif berbasis tingkat kemiripan warna pecahan (`86%` untuk grup abu-hijau `Rp2.000`/`Rp20.000`, `80%` untuk `Rp5.000`/`Rp50.000`/`Rp100.000`, dan `74%` untuk `Rp1.000`/`Rp10.000`) dikombinasikan dengan konsensus `3 frame` berturut-turut dan pemeriksaan rasio geometri kotak deteksi untuk mencegah salah baca pada uang kertas yang terlipat separuh.
3. ***Object-Presence Auto-Torch*:**
   - Memantau pencahayaan rata-rata (kanal Y pada *frame* YUV420 kamera) secara *real-time* dan menyalakan lampu senter secara otomatis ketika kondisi redup dan objek terdeteksi di depan kamera, serta mematikannya kembali saat berpindah ke layar input suara.
4. ***Smart Push-to-Talk* Respons `0 ms`:**
   - Pemrosesan transkripsi suara Bahasa Indonesia dilakukan seketika saat jari dilepas dari layar (mendukung angka standar, koreksi satu napas *"ulangi"*, hingga istilah sehari-hari seperti *"goceng"*, *"ceban"*, *"goban"*), dilengkapi papan angka aksesibel sebagai jalur cadangan.

---

## Struktur Direktori Repositori

```text
SUDEPI/
├── android/
│   └── app/src/main/kotlin/com/sudepi/app/
│       └── MainActivity.kt          # Bridge Native Kotlin: ONNX Runtime 1.23.0, YUV->RGB Letterbox, & Haptic
├── assets/
│   ├── fonts/                       # Font bundel luring Google Sans (SIL OFL 1.1)
│   ├── images/                      # Simbol merek multi-densitas (1.0x s.d. 4.0x)
│   └── models/
│       └── sudepi_yolo26n_640.onnx  # Bobot model produksi YOLO26n (640x640, FP32)
├── docs/images/                     # Aset visual dokumentasi repositori
├── lib/
│   ├── constants/sudepi_prompts.dart      # Katalog terpusat skrip panduan suara (TTS)
│   ├── models/rupiah_denomination.dart    # Definisi 7 kelas pecahan & tanda haptik
│   ├── screens/                           # 4 layar utama + pengendali alur (SudepiFlowController)
│   ├── services/                          # Layanan inferensi kamera, TTS, STT, & getaran
│   ├── theme/sudepi_theme.dart            # Sistem 8 token warna disiplin tinggi & kanvas gestur
│   ├── utils/indonesian_number_parser.dart # Parser nominal suara Bahasa Indonesia
│   └── main.dart                          # Titik masuk aplikasi Flutter
└── test/
    └── widget_test.dart             # Pengujian unit parser, skrip suara, & widget Mode Siaga
```

---

## Cara Menjalankan & Kompilasi dari Kode Sumber

### Prasyarat
- **Flutter SDK** `^3.44.x` (Dart `^3.12.1`)
- **Android SDK** (`compileSdk 36`, `minSdk 24`) & **JDK 17+**

### Langkah Eksekusi
```bash
# 1. Unduh dependensi paket
flutter pub get

# 2. Jalankan analisis statis & pengujian unit/widget
flutter analyze
flutter test

# 3. Kompilasi APK rilis terpisah per arsitektur (64-bit & 32-bit)
flutter build apk --release --split-per-abi
```

> **Catatan Penandatanganan (*App Signing*):**
> Konfigurasi [`android/app/build.gradle.kts`](./android/app/build.gradle.kts) secara otomatis menggunakan sertifikat rilis resmi apabila berkas lokal `android/key.properties` tersedia, dan otomatis beralih (*fallback*) ke kunci *debug* apabila repositori ini di-*clone* di komputer lain tanpa berkas kunci rahasia.

---

## Lisensi & Atribusi

- **Kode Sumber Aplikasi:** Dirilis di bawah [**MIT License**](./LICENSE) — Hak Cipta © 2026 Fajar Ramadhan (dikembangkan bersama tim peneliti SUDEPI).
- **Tipografi Aplikasi:** Menggunakan keluarga huruf **Google Sans** di bawah lisensi [**SIL Open Font License 1.1**](./assets/fonts/OFL.txt).
- **Dataset Pelatihan Model:** Dikurasi dari 6 repositori citra uang Rupiah terbuka berlisensi **Creative Commons Attribution 4.0 (CC BY 4.0)**.
