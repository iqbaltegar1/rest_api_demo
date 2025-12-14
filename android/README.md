# 📱 Comprehensive Testing Assignment – Flutter App

## 📌 Deskripsi Assignment

Assignment ini bertujuan untuk mengimplementasikan **comprehensive testing** pada aplikasi Flutter yang telah dibuat pada:

* **P09**: REST API
* **P10**: Offline-First SQLite

Testing tidak hanya memastikan aplikasi berjalan dengan benar, tetapi juga melatih kemampuan analisis terhadap **edge cases**, **error handling**, dan **user experience**.

📅 **Deadline**: 1 minggu setelah pertemuan ke-11
📤 **Submission**: Push ke GitHub repository dengan branch **`testing-assignment`**

---

## 🎯 Learning Objectives

Setelah menyelesaikan assignment ini, mahasiswa diharapkan mampu:

* Menulis **unit tests** untuk business logic dan data models
* Membuat **widget tests** untuk UI components dengan state management yang tepat
* Mengimplementasikan **integration tests** untuk alur pengguna secara end-to-end
* Melakukan **mocking external dependencies** (API & database)
* Menangani **error scenarios** dan **edge cases** dengan baik
* Menyusun **testing infrastructure** dengan struktur yang rapi

---

## 🧪 Testing Implementation

### 1️⃣ Unit Tests

#### ✅ Model Testing

* JSON serialization & deserialization
* Penanganan null / missing fields dari API
* Konversi data antara server model dan SQLite model
* Edge cases (string kosong, format tanggal tidak valid)

#### ✅ Provider Testing

* Load, add, update, delete task
* Transisi authentication state
* Loading & error states
* Validasi data

#### ✅ Service Testing

* Authentication scenarios (success & failure)
* CRUD API response handling
* Network error & timeout simulation
* SQLite operations & data integrity

---

### 2️⃣ Widget Tests

#### 🔐 Login Screen

* Validasi form (email & password)
* Loading state saat login
* Error message display
* Switching mode login / register

#### 📝 Task Management

* Empty state display
* Add / edit task dengan validasi form
* Toggle task completion
* Delete task dengan dialog konfirmasi
* Loading & error states

---

### 3️⃣ Integration Tests

* Login → Task Management → Logout
* Offline mode → Online sync
* Error recovery scenarios
* Performance testing dengan banyak task

---

## 🛠️ Testing Setup

### 📦 Dependencies

Tambahkan dependencies berikut pada `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
  build_runner: ^2.4.6
  integration_test:
    sdk: flutter
  sqflite_common_ffi: ^2.3.0
```

---

### 🗄️ Database Testing

* Menggunakan **in-memory SQLite database**
* Database test terpisah dari production
* Setup & teardown otomatis pada test

---

### 🧩 Mocking Strategy

Mock digunakan untuk:

* HTTP Client (REST API)
* SQLite repository
* External services
* Platform-specific features

---

### ⚙️ Test Environment

* Konfigurasi database khusus testing
* Mock API endpoints
* Test data fixtures
* Environment variables untuk test

---

## 📂 Struktur Folder Testing

```
project_root/
├── lib/
├── test/
│   ├── models/
│   ├── providers/
│   ├── services/
│   └── widgets/
├── integration_test/
├── pubspec.yaml
├── README.md
```

---

## 🚀 Cara Menjalankan Test

### Unit & Widget Tests

```bash
flutter test
```

### Integration Tests

```bash
flutter test integration_test
```

---

## 📤 Submission Checklist

* [x] Unit tests implemented
* [x] Widget tests implemented
* [x] Integration tests implemented
* [x] Mocking external dependencies
* [x] README.md tersedia
* [x] Branch: `testing-assignment`

---

## 👨‍🎓 Author

**Nama Mahasiswa**: *IQBAL TEGAR PRATAMA*
**NIM**: *A11.2023.14969*
**Mata Kuliah**: PEMROGRAMAN PRANGKAT BERGERAK

---

✨ *Assignment ini berfokus pada kualitas, bukan hanya kuantitas test. Pastikan setiap test merepresentasikan skenario nyata pengguna.*
