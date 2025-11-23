# Parking Finder - Flutter App

Aplikasi pencarian tempat parkir berbasis crowdsourcing yang membantu pengguna menemukan lokasi parkir terdekat dengan informasi real-time tentang ketersediaan slot.

## Fitur Utama (MVP)

### ✅ Map View (Peta Lokasi Parkir Terdekat)
- Menampilkan lokasi parkir dalam radius pengguna
- Status visual dengan warna: Hijau (banyak kosong), Kuning (mulai penuh), Merah (penuh)
- Menampilkan jarak dan estimasi waktu jalan kaki
- Navigasi ke lokasi parkir

### ✅ Parking Status (Crowdsourced)
- User dapat melaporkan status parkir
- Update status real-time
- Sistem reward/poin untuk kontributor

### ✅ Detail Lokasi Parkir
- Informasi harga parkir (motor/mobil)
- Jam buka dan kapasitas total
- Informasi keamanan (CCTV, pencahayaan)
- Layout dan foto lokasi

### ✅ Petunjuk Lokasi Parkir
- Simpan lokasi kendaraan setelah parkir
- Fitur cari kendaraan dengan arah kompas
- Notifikasi reminder

## Teknologi yang Digunakan

- **Flutter** - Framework UI cross-platform
- **Google Maps SDK** - Peta dan navigasi
- **Geolocator & Location** - Layanan lokasi
- **Provider** - State management
- **Material Design 3** - Desain modern

## Instalasi

### Prasyarat
- Flutter SDK (latest stable)
- Android Studio / Xcode
- Google Maps API Key

### Setup

1. Clone repository
```bash
git clone https://github.com/yourusername/parking_finder.git
cd parking_finder
```

2. Install dependencies
```bash
flutter pub get
```

3. Setup Google Maps API Key

#### Android
Edit file `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE" />
```

#### iOS
Edit file `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
```

4. Jalankan aplikasi
```bash
flutter run
```

## Struktur Proyek

```
lib/
├── constants/          # Konstanta dan konfigurasi
│   ├── app_colors.dart
│   └── app_constants.dart
├── controllers/        # State management
│   └── map_controller.dart
├── models/            # Data models
│   ├── parking_location.dart
│   └── user_location.dart
├── screens/           # UI screens
│   └── home/
│       └── home_screen.dart
├── services/          # Business logic
│   └── location_service.dart
├── utils/            # Utility functions
└── widgets/          # Reusable widgets
    └── map_view.dart
```

## Fitur yang Akan Datang

- [ ] Sistem login dengan email/Google
- [ ] Filter pencarian lanjutan
- [ ] Favorite parking spots
- [ ] Reminder durasi parkir
- [ ] Gamification dengan poin dan badge
- [ ] Chat dan diskusi area
- [ ] Integrasi dengan IoT untuk real-time occupancy
- [ ] Sistem booking dan pembayaran

## Kontribusi

Kami menyambut kontribusi dari komunitas! Silakan buka issue atau pull request.

## Lisensi

Proyek ini dilisensikan di bawah MIT License.

## Tim Pengembang

- Developer: [Your Name]
- Designer: [Designer Name]
- Product Manager: [PM Name]

## Catatan

Aplikasi ini masih dalam tahap pengembangan MVP. Beberapa fitur mungkin belum tersedia atau masih dalam bentuk mock data.

Untuk bug report atau feature request, silakan buka issue di repository ini.
