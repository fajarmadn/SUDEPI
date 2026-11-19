<p align="center">
  <img src="./docs/images/sudepi-banner.png" alt="SUDEPI - Suara Deteksi Rupiah" width="560" />
</p>

<p align="center">
  Aplikasi Android untuk mendeteksi uang kertas Rupiah dan memverifikasi uang kembalian bagi penyandang tunanetra, berbasis visi komputer dan berjalan sepenuhnya tanpa koneksi internet.
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

SUDEPI (Suara Deteksi Rupiah) adalah aplikasi Android yang membantu penyandang tunanetra dan low vision mengenali tujuh pecahan uang kertas Rupiah Tahun Emisi 2016 dan 2022 (Rp1.000 sampai Rp100.000) serta memeriksa uang kembalian belanja secara bertahap. Antarmukanya dirancang tanpa tombol: seluruh interaksi dilakukan melalui gestur pada layar penuh, dengan dukungan panduan suara dan getaran.

Deteksi uang (YOLO26n dengan ONNX Runtime), panduan suara (text-to-speech Bahasa Indonesia), dan umpan balik getaran semuanya berjalan di perangkat. Aplikasi tidak memerlukan internet, tidak menampilkan iklan, dan tidak mengirim gambar kamera maupun rekaman suara ke server mana pun.

---

## Unduh Aplikasi

Berkas instalasi (.apk) tersedia di halaman [GitHub Releases](https://github.com/fajarmadn/SUDEPI/releases/latest). Pilih sesuai arsitektur perangkat Android Anda.

| Paket Instalasi | Perangkat yang Didukung | Ukuran | Tautan Unduh |
| :--- | :--- | :---: | :---: |
| `SUDEPI-arm64-v8a.apk` (direkomendasikan) | Sebagian besar ponsel Android 64-bit (rilis sekitar 2018 ke atas) | ~45,5 MB | [Unduh 64-bit](https://github.com/fajarmadn/SUDEPI/releases/latest/download/SUDEPI-arm64-v8a.apk) |
| `SUDEPI-armeabi-v7a.apk` | Ponsel Android 32-bit atau kelas entri (minimal Android 7.0 Nougat) | ~37,8 MB | [Unduh 32-bit](https://github.com/fajarmadn/SUDEPI/releases/latest/download/SUDEPI-armeabi-v7a.apk) |

### Petunjuk Instalasi

1. Buka berkas .apk yang telah diunduh. Jika diminta, izinkan opsi "Instal aplikasi yang tidak dikenal" untuk peramban atau pengelola berkas yang digunakan.
2. Saat pertama kali dibuka, berikan izin Kamera (untuk memindai uang) dan Mikrofon (untuk menyebutkan nominal belanja).
3. Pastikan mesin suara Bahasa Indonesia dari Google (Speech Recognition & Synthesis) aktif pada pengaturan Text-to-Speech di ponsel agar panduan suara terdengar dengan baik.

---

## Panduan Penggunaan

SUDEPI menggunakan layar penuh sebagai area gestur, sehingga pengguna tidak perlu mencari tombol kecil. Alur aplikasi terdiri dari empat layar yang berurutan.

| Layar | Ketuk 1x | Ketuk 2x | Tahan Layar | Usap ke Kiri (maju) | Usap ke Kanan (mundur) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1. Mode Siaga (deteksi satu lembar) | Mengulang panduan atau membacakan nominal yang terdeteksi | Menyalakan atau mematikan senter kamera | - | Memulai transaksi belanja (ke Layar 2) | - |
| 2. Total Belanja (input suara atau angka) | Membacakan status nominal belanja | Membuka atau menutup papan angka cadangan | Push-to-talk: tahan layar, sebutkan total belanja, lalu lepaskan | Lanjut ke Uang Diberikan (Layar 3) | Kembali ke Mode Siaga |
| 3. Uang Diberikan (input suara atau angka) | Membacakan uang yang dibayarkan dan menghitung kembalian | Membuka atau menutup papan angka cadangan | Push-to-talk: tahan layar dan sebutkan uang yang dibayarkan | Memulai pemindaian uang kembalian (jika ada kembalian) | Kembali ke Total Belanja |
| 4. Cek Kembalian (pemindaian bertahap) | Membacakan target kembalian, jumlah terkumpul, dan sisa | Menyalakan atau mematikan senter kamera | Mengulang hitungan kembalian dari Rp0 | Menyelesaikan transaksi (kembali ke Mode Siaga) | Kembali ke Uang Diberikan |

### Pola Getaran per Pecahan

Selain menyebutkan nominal melalui suara, SUDEPI memberikan pola getaran yang berbeda untuk setiap pecahan. Pola ini membantu pengguna mengonfirmasi hasil deteksi di lingkungan yang bising.

- Rp1.000, Rp2.000, dan Rp5.000: masing-masing 1, 2, dan 3 getaran pendek (55 ms).
- Rp10.000, Rp20.000, dan Rp50.000: masing-masing 1, 2, dan 3 getaran sedang (150 ms).
- Rp100.000: 1 getaran panjang (420 ms).

---

## Fitur Teknis dan Spesifikasi Model

1. Detektor YOLO26n end-to-end tanpa NMS (ONNX FP32, 9,49 MB)
   - Model dilatih pada 88.387 citra uang kertas Rupiah yang telah dikurasi, dengan pembagian data tanpa kebocoran antar-kelompok: 81.407 citra latih, 3.490 citra validasi, dan 3.490 citra uji.
   - Pada data uji, model mencapai mAP@50 sebesar 99,28% (precision 98,94%, recall 98,53%, mAP@50:95 93,86%). Rata-rata waktu inferensi di CPU adalah 24,96 ms per citra.
   - Keluaran model berupa tensor `[1, 300, 6]` yang langsung dapat dipakai, sehingga tidak memerlukan pascaproses Non-Maximum Suppression (NMS).

2. Gerbang kepercayaan tiga tingkat dan penanganan uang terlipat
   - Ambang kepercayaan disesuaikan dengan kemiripan warna antar pecahan: 86% untuk Rp2.000 dan Rp20.000 (kelompok abu-hijau), 80% untuk Rp5.000, Rp50.000, dan Rp100.000, serta 74% untuk Rp1.000 dan Rp10.000.
   - Hasil diterima setelah tiga frame berturut-turut mengonfirmasi pecahan yang sama. Rasio geometri kotak deteksi juga diperiksa untuk mencegah salah baca pada uang yang terlipat separuh.

3. Senter otomatis berdasarkan keberadaan objek
   - Tingkat pencahayaan rata-rata (kanal Y pada frame YUV420 dari kamera) dipantau secara real-time. Senter menyala otomatis saat kondisi redup dan ada objek di depan kamera, lalu dimatikan ketika pengguna berpindah ke layar input suara.

4. Push-to-talk dengan transkripsi langsung
   - Transkripsi suara Bahasa Indonesia diproses begitu jari dilepas dari layar. Parser mendukung angka standar, koreksi dalam satu ucapan dengan kata "ulangi", serta istilah sehari-hari seperti "goceng", "ceban", dan "goban".
   - Papan angka yang aksesibel tersedia sebagai alternatif input.

---

## Struktur Direktori

```text
SUDEPI/
├── android/
│   └── app/src/main/kotlin/com/sudepi/app/
│       └── MainActivity.kt          # Bridge native Kotlin: ONNX Runtime 1.23.0, konversi YUV ke RGB (letterbox), dan haptic
├── assets/
│   ├── fonts/                       # Font Google Sans yang dibundel (SIL OFL 1.1)
│   ├── images/                      # Aset merek multi-densitas (1.0x sampai 4.0x)
│   └── models/
│       └── sudepi_yolo26n_640.onnx  # Bobot model produksi YOLO26n (640x640, FP32)
├── docs/images/                     # Aset visual untuk dokumentasi
├── lib/
│   ├── constants/sudepi_prompts.dart      # Katalog skrip panduan suara (TTS)
│   ├── models/rupiah_denomination.dart    # Definisi 7 kelas pecahan dan pola haptic
│   ├── screens/                           # Empat layar utama dan pengendali alur (SudepiFlowController)
│   ├── services/                          # Layanan inferensi kamera, TTS, STT, dan getaran
│   ├── theme/sudepi_theme.dart            # Sistem tema 8 token warna dan kanvas gestur
│   ├── utils/indonesian_number_parser.dart # Parser nominal dari ucapan Bahasa Indonesia
│   └── main.dart                          # Titik masuk aplikasi Flutter
└── test/
    └── widget_test.dart             # Pengujian parser, skrip suara, dan widget Mode Siaga
```

---

## Menjalankan dan Membangun dari Kode Sumber

### Prasyarat

- Flutter SDK `^3.44.x` (Dart `^3.12.1`)
- Android SDK (`compileSdk 36`, `minSdk 24`) dan JDK 17 atau lebih baru

### Langkah-langkah

```bash
# 1. Unduh dependensi
flutter pub get

# 2. Jalankan analisis statis dan pengujian
flutter analyze
flutter test

# 3. Bangun APK rilis per arsitektur (64-bit dan 32-bit)
flutter build apk --release --split-per-abi
```

### Penandatanganan Aplikasi

Konfigurasi di [`android/app/build.gradle.kts`](./android/app/build.gradle.kts) memakai sertifikat rilis jika berkas lokal `android/key.properties` tersedia. Jika repositori di-clone tanpa berkas tersebut, proses build otomatis memakai kunci debug.

---

## Lisensi dan Atribusi

- Kode sumber aplikasi dirilis di bawah [MIT License](./LICENSE). Hak Cipta © 2026 Fajar Ramadhan (dikembangkan bersama tim peneliti SUDEPI).
- Tipografi aplikasi menggunakan keluarga huruf Google Sans di bawah lisensi [SIL Open Font License 1.1](./assets/fonts/OFL.txt).
- Dataset pelatihan dikurasi dari enam repositori citra uang Rupiah terbuka berlisensi Creative Commons Attribution 4.0 (CC BY 4.0).
