# Configuration

## Google Maps API Key

Untuk menjalankan aplikasi ini, Anda memerlukan Google Maps API Key. Ikuti langkah-langkah berikut:

### 1. Dapatkan API Key dari Google Cloud Console

1. Kunjungi [Google Cloud Console](https://console.cloud.google.com/)
2. Buat project baru atau pilih project yang ada
3. Aktifkan API berikut:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Directions API (opsional untuk navigasi)
4. Buat API Key di bagian Credentials
5. Batasi API Key Anda dengan:
   - Aplikasi Android: Package name dan SHA-1 fingerprint
   - Aplikasi iOS: Bundle ID

### 2. Setup API Key di Aplikasi

#### Android
Edit file: `android/app/src/main/AndroidManifest.xml`

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE" />
```

#### iOS
Edit file: `ios/Runner/AppDelegate.swift`

```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
```

### 3. Dapatkan SHA-1 Fingerprint (Android)

```bash
cd android
./gradlew signingReport
```

Atau gunakan command:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### 4. Testing API Key

Untuk memastikan API Key berfungsi:

1. Jalankan aplikasi
2. Peta harus menampilkan lokasi Jakarta (default)
3. Cek log untuk error terkait Google Maps

### 5. Troubleshooting

Jika peta tidak muncul:
- Periksa API Key sudah benar
- Pastikan API sudah diaktifkan di Google Cloud Console
- Cek billing account sudah terhubung
- Periksa package name dan SHA-1 sudah sesuai

### 6. Best Practices

- Jangan commit API Key ke repository
- Gunakan environment variables untuk production
- Batasi API Key dengan proper restrictions
- Monitor usage di Google Cloud Console
- Setup billing alerts untuk menghindari tagihan yang tidak terduga