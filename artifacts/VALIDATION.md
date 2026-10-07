# Kết quả kiểm tra bản 0.1.0

- `flutter analyze`: không có lỗi hoặc cảnh báo.
- `flutter test`: 11 tests đạt, gồm luồng UI, root gate, selection, ngôn ngữ/chủ đề và màn hình 320×640 có insets.
- `cargo test`: 8 tests đạt. Shell harness xác minh split APK/native library, bảo toàn dữ liệu, checksum sai và rollback khi xuất module thứ hai thất bại.
- Clippy host và Android ARM64 với `-D warnings`: đạt.
- Build release ARM64 và universal: đạt.
- Chữ ký APK được `apksigner verify` xác nhận; bản thử nghiệm dùng debug key.
- `zipalign -c -P 16 4`: đạt cho cả hai APK.
- ELF của mọi thư viện 64-bit có segment alignment tối thiểu 16KB.
- ARM64 APK chỉ chứa ABI `arm64-v8a`; universal chứa đủ Flutter, Dart AOT và Rust core cho ARM64/ARMv7/x86_64.
- Manifest: minSdk 30 (Android 11), targetSdk 36, QUERY_ALL_PACKAGES và ACCESS_SUPERUSER; release không khai báo INTERNET.

Ảnh xem trước dùng widget Flutter thật và inventory giả trong test. Chưa chạy mount/reboot/systemize trên điện thoại root thật. Quy trình cần kiểm tra trên thiết bị nằm trong `docs/DEVICE_TESTING.md`.
