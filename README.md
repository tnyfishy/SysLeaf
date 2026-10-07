# SysLeaf

Ứng dụng Android **Flutter + Rust** để chọn một hoặc nhiều app người dùng và tạo module systemless. App được nhận diện là **ngân hàng dùng `/system/app`**; các app khác dùng **`/system_ext/priv-app`**. Giao diện Material 3, mặc định tiếng Việt. Phiên bản hiện tại: **1.1**.

## Cài và sử dụng

1. Cài APK trên **Android 11 trở lên**, trong hồ sơ chủ thiết bị (**user 0**).
2. Mở SysLeaf và cấp quyền **`su`** trong Magisk hoặc KernelSU. Khi chưa có root, chỉ màn hình yêu cầu quyền được hiển thị.
3. Với **KernelSU**, cài và bật [Hybrid Mount](https://github.com/Hybrid-Mount/meta-hybrid_mount/releases), dùng backend **OverlayFS** hoặc **Magic Mount**, rồi khởi động lại. Cấu hình phải quét `/data/adb/modules` và không bỏ qua module `sysleaf_*`.
4. Với **Magisk**, SysLeaf dùng Magic Mount có sẵn. **Hybrid Mount upstream hiện hỗ trợ KernelSU/APatch, không hỗ trợ cài qua Magisk.**
5. Vào **Ứng dụng**, chọn app riêng lẻ hoặc **Chọn theo nhóm** (mạng xã hội/ngân hàng), bấm **Systemize**, kiểm tra danh sách rồi chọn **Vâng!😋** hoặc **Khoan đã😐**.
6. Khởi động lại bằng nút ở đầu app. Module mới hiển thị **Chờ khởi động lại** cho đến khi Android thực sự nhận package là ứng dụng hệ thống.

Module đang tắt, chờ gỡ hoặc chưa mount được có trạng thái riêng. Menu cạnh app do SysLeaf quản lý cho phép **Gỡ module**; thao tác này áp dụng sau khi khởi động lại.

Nếu đã tạo module ngân hàng bằng bản cũ, mở **Trang chủ → Chuyển module ngân hàng**, xem lại danh sách và xác nhận chuyển sang `/system/app`, rồi khởi động lại. SysLeaf giữ APK/split/thư viện và marker tắt module, không chuyển dữ liệu riêng. Bản sao module cũ ở `/data/adb/.sysleaf-bank-backup-*` được giữ đến khi script của module xác minh APK tại đường dẫn mới sau một lần boot khác. Module đang tắt giữ bản sao lâu hơn, đến khi được bật và mount đúng.

## Vô hiệu hoá hoặc gỡ nhiều ứng dụng

Trong tab **Ứng dụng**, chọn chế độ **Vô hiệu hoá** hoặc **Gỡ ứng dụng**, rồi chọn một/nhiều app bằng checkbox hoặc **Chọn theo nhóm**. Hai chế độ này nhận cả app người dùng, app hệ thống có sẵn và app đã systemize; không cần Hybrid Mount để thực hiện. Đổi chế độ sẽ bỏ lựa chọn cũ để tránh áp dụng nhầm thao tác. Giới hạn 100 app/lần; SysLeaf không cho vô hiệu hoá/gỡ chính nó hoặc gói framework `android`.

Trước mỗi thao tác, hộp thoại hiển thị tên, mã gói, biểu tượng và dấu nhận diện app hệ thống/module của toàn bộ app đã chọn. Cảnh báo nêu rõ gỡ/vô hiệu hoá ứng dụng hệ thống có thể khiến thiết bị hoạt động không đúng cách hoặc **bootloop**. Chỉ chạy khi chọn **Được, cứ làm đi!**; **Oh, chờ chút**, nút Back hoặc đóng hộp thoại sẽ huỷ.

- **Vô hiệu hoá:** chạy `pm disable-user --user 0 <package>`, giữ dữ liệu của ứng dụng và đọc lại trạng thái disabled để xác nhận.
- **Gỡ ứng dụng:** chạy `pm uninstall --user 0 <package>`, gỡ khỏi hồ sơ chủ thiết bị và xoá dữ liệu app trong hồ sơ này. Không xoá trực tiếp APK trên phân vùng hệ thống hoặc thư mục module. Gỡ ứng dụng khác với **Gỡ module**; module đang tồn tại vẫn được giữ.
- Backend đọc lại PackageManager, kiểm tra toàn bộ lựa chọn trước khi thay đổi, giữ lock và xử lý từng app. Lỗi ở một app không ngăn xử lý app tiếp theo; kết quả báo riêng thành công/thất bại kèm chi tiết Android. Những app thất bại còn đủ điều kiện vẫn được chọn để xem lại. Thao tác này không có rollback tự động.
- Sau lỗi hoặc timeout, danh sách vẫn được làm mới để phản ánh cả thay đổi đã áp dụng. Không cần khởi động lại để thực hiện disable/uninstall.

Trong hồ sơ owner (**user 0**), có thể khôi phục qua ADB/root:

```bash
adb shell su -c 'pm enable --user 0 com.example.app'
# Chỉ khi APK hệ thống/module còn được Android nhận diện:
adb shell su -c 'pm install-existing --user 0 com.example.app'
```

Thay mã gói bằng app cần khôi phục. `install-existing` không khôi phục dữ liệu đã bị xoá. Với app người dùng đã gỡ và không còn APK được Android nhận diện, cần cài lại từ APK/cửa hàng. Xem [kiểm tra và khôi phục trên thiết bị](docs/DEVICE_TESTING.md).

## Có gì trong app

- Ba tab **Trang chủ / Ứng dụng / Cài đặt**.
- Ngôn ngữ **🇻🇳 tiếng Việt / 🇺🇸 English**, lưu lựa chọn trên thiết bị. Cờ được vẽ bằng Flutter để không phụ thuộc font emoji của ROM.
- Giao diện **theo hệ thống / sáng / tối / đen tuyền**, lưu lựa chọn.
- Chuyển tab bằng fade/slide, mở mục bằng AnimatedSize, hộp thoại fade/scale, chuyển chủ đề có animation. Tôn trọng tùy chọn giảm chuyển động của hệ điều hành.
- `SafeArea`, đơn vị logical pixel, bố cục giới hạn chiều rộng và danh sách lazy cho màn hình có tai thỏ/status bar.
- Danh sách tên, mã gói và icon thật từ Android PackageManager; khai báo `QUERY_ALL_PACKAGES`.
- Ô tìm kiếm đứng trước menu **Systemize / Vô hiệu hoá / Gỡ ứng dụng**; chip được chọn đổi màu và không có dấu tích đè lên icon.
- Tìm tên/mã gói, lọc nhóm và sắp xếp theo tên, **ứng dụng đã systemize / đã vô hiệu hoá / đã gỡ cài đặt**, mạng xã hội/ngân hàng 🏦. App hệ thống và app có module được ghim lên đầu; sort trạng thái đưa trạng thái được chọn lên trước.
- Mục đã gỡ dùng metadata Android còn giữ và lịch sử cục bộ từ lần SysLeaf nhìn thấy app. App người dùng đã gỡ trước khi dùng bản 1.1 và bị Android quên sẽ không thể được truy lại. Cài lại app sẽ cập nhật trạng thái. App đã gỡ chỉ dùng để xem lại, không thể chọn disable/uninstall lần nữa.
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

Module ngân hàng dùng cấu trúc sau, không tạo privileged permission XML:

```text
/data/adb/modules/sysleaf_com.example.bank/
├── module.prop
├── .sysleaf-managed
├── package
├── installed_boot_id
└── system/app/com.example.bank/
    ├── base.apk
    ├── split_*.apk
    └── lib/...
```

SysLeaf không gọi lệnh cấp thêm quyền signature/privileged. Với app khác ngân hàng trong `priv-app`, XML trong cùng phân vùng chứa `deny-permission` cho các quyền privileged từ framework và CarService mà app yêu cầu, nhằm tuân thủ chế độ allowlist của Android. Quyền do nhà sản xuất định nghĩa vẫn phụ thuộc chính sách của ROM. Đưa app ngân hàng vào `/system/app` không bảo đảm vượt kiểm tra root/integrity của ngân hàng.

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

GitHub Actions tạo debug key mới cho mỗi lần chạy; APK 1.1 không cài đè được nếu chữ ký khác bản đang dùng. Khi Android báo xung đột chữ ký, gỡ **SysLeaf** cũ rồi cài APK mới. Module trong `/data/adb/modules` vẫn còn; lựa chọn giao diện và lịch sử riêng của SysLeaf bị xoá. Không gỡ ứng dụng ngân hàng để cập nhật SysLeaf.

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

Tests quản lý app kiểm tra hủy/xác nhận hai thao tác với nhiều app hệ thống/người dùng, danh sách được xác nhận không thay đổi theo selection, cảnh báo Anh/Việt, kết quả lỗi một phần, timeout và màn hình 320×640. Shell harness dùng PackageManager giả để kiểm tra `--user 0`, mã thoát lỗi, thông báo `Failure` dù exit 0, lệnh báo `Success` nhưng trạng thái không đổi, lỗi truy vấn trạng thái, preflight và lock. Không chạy disable/uninstall thật trên máy build.

Bản 1.1 bổ sung kiểm tra copy mới/ngân hàng đúng đích, chuyển module cũ giữ split/library và trạng thái disabled, rollback cả batch khi publish lỗi, và chỉ dọn bản sao sau boot khác khi APK đã mount đúng. Lịch sử gỡ/cài lại, sort trạng thái, nội dung theo ảnh và huỷ/xác nhận chuyển module được kiểm tra riêng. Xem [kết quả bản 1.1](artifacts/VALIDATION-1.1.0.md).

Ảnh trong `artifacts/screenshots` được render bằng widget Flutter thật với danh sách app giả **chỉ trong test**. Bản chạy thực tế không có demo mode hay cơ chế bỏ qua root.

**Chưa kiểm thử mount/reboot trên thiết bị Magisk/KernelSU thật trong môi trường này.** Trước khi dùng hàng loạt, thử một app, khởi động lại và xác nhận trạng thái trong tab Ứng dụng. Nếu module vẫn ghi **Chưa được mount**, kiểm tra engine, quy tắc Hybrid Mount và log của trình quản lý root. Xem [quy trình kiểm tra thiết bị](docs/DEVICE_TESTING.md).

## Mã nguồn

- `lib/`: giao diện Flutter, localization, trạng thái và Dart FFI.
- `rust/src/android.rs`: Android JNI và đọc PackageManager.
- `rust/src/root.rs`: thực thi `su` ngoài UI thread, timeout, stream script.
- `rust/src/modules.rs`: kiểm tra selection, copy/checksum, module và rollback.
- `rust/src/app_management.rs`: disable/uninstall nhiều app, xác minh trạng thái và kết quả từng app.
- `rust/src/history.rs`: lưu lịch sử app cục bộ để xem lại app đã gỡ.
- `test/`: kiểm tra widget/controller; mock chỉ dùng trong test.
- [Kiến trúc](docs/ARCHITECTURE.md), [kiểm tra thiết bị](docs/DEVICE_TESTING.md).

Mã SysLeaf dùng MIT. Font Manrope dùng SIL OFL, license kèm trong `assets/fonts/OFL.txt`. Hybrid Mount là dependency cài riêng, không được nhúng hoặc phân phối trong APK.
