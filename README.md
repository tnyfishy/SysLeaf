# SysLeaf

Ứng dụng Android **Flutter + Rust** để chọn một hoặc nhiều app người dùng và tạo module systemless đưa APK vào **`/system_ext/priv-app`**. Giao diện Material 3, mặc định tiếng Việt.

## Cài và sử dụng

1. Cài APK trên **Android 11 trở lên**, trong hồ sơ chủ thiết bị (**user 0**).
2. Mở SysLeaf và cấp quyền **`su`** trong Magisk hoặc KernelSU. Khi chưa có root, chỉ màn hình yêu cầu quyền được hiển thị.
3. Với **KernelSU**, cài và bật [Hybrid Mount](https://github.com/Hybrid-Mount/meta-hybrid_mount/releases), dùng backend **OverlayFS** hoặc **Magic Mount**, rồi khởi động lại. Cấu hình phải quét `/data/adb/modules` và không bỏ qua module `sysleaf_*`.
4. Với **Magisk**, SysLeaf dùng Magic Mount có sẵn. **Hybrid Mount upstream hiện hỗ trợ KernelSU/APatch, không hỗ trợ cài qua Magisk.**
5. Vào **Ứng dụng**, chọn app riêng lẻ hoặc **Chọn theo nhóm** (mạng xã hội/ngân hàng), bấm **Systemize**, kiểm tra danh sách rồi chọn **Vâng!😋** hoặc **Khoan đã😐**.
6. Khởi động lại bằng nút ở đầu app. Module mới hiển thị **Chờ khởi động lại** cho đến khi Android thực sự nhận package là ứng dụng hệ thống.

Module đang tắt, chờ gỡ hoặc chưa mount được có trạng thái riêng. Menu cạnh app do SysLeaf quản lý cho phép **Gỡ module**; thao tác này áp dụng sau khi khởi động lại.

## Có gì trong app

- Ba tab **Trang chủ / Ứng dụng / Cài đặt**.
- Ngôn ngữ **🇻🇳 tiếng Việt / 🇺🇸 English**, lưu lựa chọn trên thiết bị. Cờ được vẽ bằng Flutter để không phụ thuộc font emoji của ROM.
- Giao diện **theo hệ thống / sáng / tối / đen tuyền**, lưu lựa chọn.
- Chuyển tab bằng fade/slide, mở mục bằng AnimatedSize, hộp thoại fade/scale, chuyển chủ đề có animation. Tôn trọng tùy chọn giảm chuyển động của hệ điều hành.
- `SafeArea`, đơn vị logical pixel, bố cục giới hạn chiều rộng và danh sách lazy cho màn hình có tai thỏ/status bar.
- Danh sách tên, mã gói và icon thật từ Android PackageManager; khai báo `QUERY_ALL_PACKAGES`.
- Tìm tên/mã gói, lọc nhóm và sắp xếp theo tên/systemize/mạng xã hội/ngân hàng 🏦. App hệ thống và app có module được ghim lên đầu.
- Chọn nhiều app, tối đa 100 app/lần; preset dựa vào mã gói đã biết và `ApplicationInfo.CATEGORY_SOCIAL`. **Nhận diện ngân hàng không bao phủ mọi app**, nên luôn có bước xem lại danh sách.
- Không có máy chủ; danh sách app và cấu hình được xử lý trên thiết bị. Link Hybrid Mount mở bằng trình duyệt của bạn.

## APK và dữ liệu người dùng

Đường dẫn chuẩn là **`priv-app`**, có dấu gạch ngang. SysLeaf sao chép **base APK, toàn bộ split APK và thư viện native** vào module:

```text
/data/adb/modules/sysleaf_com.example.app/
├── module.prop
├── .sysleaf-managed
├── package
├── installed_boot_id
└── system/system_ext/
    ├── priv-app/com.example.app/
    │   ├── base.apk
    │   ├── split_*.apk
    │   └── lib/...
    └── etc/permissions/privapp-sysleaf-com.example.app.xml
```

Magisk/Hybrid Mount ánh xạ nội dung này vào `/system_ext`. SysLeaf ghi vào vùng module trong `/data`, nên không cần sửa trực tiếp phân vùng system_ext vật lý thường chỉ đọc.

**Dữ liệu riêng không được chuyển sang system_ext.** Tài khoản, cơ sở dữ liệu, cache và cài đặt ở `/data/user/0/<package>` và `/data/user_de/0/<package>` được giữ nguyên. Bản cài trong `/data/app` cũng được giữ lại để Android có thể xử lý app như bản cập nhật của ứng dụng hệ thống và để gỡ module có thể trở về app người dùng.

SysLeaf không gọi lệnh cấp thêm quyền signature/privileged. XML trong cùng phân vùng chứa `deny-permission` cho các quyền privileged từ framework và CarService mà app yêu cầu, nhằm tuân thủ chế độ allowlist của Android. Quyền do nhà sản xuất định nghĩa vẫn phụ thuộc chính sách của ROM.

APK của module là bản chụp tại thời điểm tạo. Muốn cập nhật bản chụp, gỡ module, khởi động lại và tạo lại từ phiên bản app mới. Systemize không thay đổi chữ ký APK hoặc trạng thái integrity của thiết bị.

## Build

Đã build với Flutter **3.35.4**, Dart **3.9.2**, Rust **1.99.0**, JDK **21**, SDK **36**, NDK **27.0.12077973**, cargo-ndk **4.1.2**. Có thể dùng Linux/macOS với Android SDK và Flutter trong `PATH`.

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install cargo-ndk --version 4.1.2 --locked
sdkmanager 'platforms;android-36' 'build-tools;35.0.0' 'ndk;27.0.12077973' 'cmake;3.22.1'
flutter pub get
flutter build apk --release
```

Gradle tự build Rust cho ABI Flutter yêu cầu và đóng gói `libsysleaf_core.so`. Không cần chạy code generator hoặc flutter_rust_bridge; cầu nối là Dart FFI JSON có giải phóng bộ nhớ ở Rust.

- APK universal: `build/app/outputs/flutter-apk/app-release.apk` (ARM64, ARMv7, x86_64).
- Chỉ ARM64: `flutter build apk --release --target-platform android-arm64`.
- Tách ABI: `flutter build apk --release --split-per-abi`.
- Chạy khi phát triển: `flutter run` (vẫn cần Android root để vào chức năng chính).

**APK đi kèm là bản thử nghiệm ký bằng debug key.** Cấu hình signing bằng keystore riêng trước khi phát hành production. File keystore không được đưa vào mã nguồn.

Giao diện và logic ứng dụng nằm hoàn toàn trong Dart/Flutter và Rust. `MainActivity.java` là bootstrap Android tối thiểu: nạp thư viện và chuyển Application context sang JNI trước khi Flutter khởi chạy. Mọi thao tác PackageManager, quyền, icon, lưu cấu hình, `su`, tạo/gỡ module đều nằm trong Rust. Gradle Kotlin DSL chỉ là cấu hình build.

## Kiểm tra

```bash
flutter analyze
flutter test
cd rust
cargo test
cargo clippy --all-targets -- -D warnings
cargo ndk -t arm64-v8a clippy --release -- -D warnings
```

Tests kiểm tra root gate, mất quyền root, chọn nhóm, hủy/xác nhận systemize, restart, ngôn ngữ, chủ đề đen và màn hình hẹp. Rust tests chạy shell giao dịch trong thư mục tạm, dùng APK/split/library giả để kiểm tra sao chép, bảo toàn dữ liệu và dọn trạng thái khi lỗi; không ghi vào phân vùng Android thật.

Ảnh trong `artifacts/screenshots` được render bằng widget Flutter thật với danh sách app giả **chỉ trong test**. Bản chạy thực tế không có demo mode hay cơ chế bỏ qua root.

**Chưa kiểm thử mount/reboot trên thiết bị Magisk/KernelSU thật trong môi trường này.** Trước khi dùng hàng loạt, thử một app, khởi động lại và xác nhận trạng thái trong tab Ứng dụng. Nếu module vẫn ghi **Chưa được mount**, kiểm tra engine, quy tắc Hybrid Mount và log của trình quản lý root. Xem [quy trình kiểm tra thiết bị](docs/DEVICE_TESTING.md).

## Mã nguồn

- `lib/`: giao diện Flutter, localization, trạng thái và Dart FFI.
- `rust/src/android.rs`: Android JNI và đọc PackageManager.
- `rust/src/root.rs`: thực thi `su` ngoài UI thread, timeout, stream script.
- `rust/src/modules.rs`: kiểm tra selection, copy/checksum, module và rollback.
- `test/`: kiểm tra widget/controller; mock chỉ dùng trong test.
- [Kiến trúc](docs/ARCHITECTURE.md), [kiểm tra thiết bị](docs/DEVICE_TESTING.md).

Mã SysLeaf dùng MIT. Font Manrope dùng SIL OFL, license kèm trong `assets/fonts/OFL.txt`. Hybrid Mount là dependency cài riêng, không được nhúng hoặc phân phối trong APK.
