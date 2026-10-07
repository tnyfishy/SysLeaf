# Kiến trúc SysLeaf

```mermaid
flowchart TD
  UI[Flutter Material 3] --> State[AppController]
  State --> Worker[Worker isolate + Dart FFI]
  Worker --> Core[Rust core]
  Core --> JNI[Public Android JNI APIs]
  JNI --> PM[PackageManager: app, icon, APK, permission]
  Core --> SU[su + shell stdin]
  SU --> Staging[Stage từng module + kiểm tra APK]
  Staging --> Modules[/data/adb/modules/sysleaf_package]
  Modules --> Engine[Magisk Magic Mount hoặc KSU Hybrid Mount]
  Engine --> Target[/system_ext/priv-app sau reboot]
```

Application context được Android entry point chuyển sang Rust bằng một lời gọi JNI. Rust giữ JavaVM và GlobalRef; mỗi worker attach vào JVM, dùng local frames và detach qua RAII. Không gọi hidden API, không dùng MethodChannel và không có Kotlin chứa logic app.

## Quy trình cài

1. Đọc lại inventory từ PackageManager để không tin metadata/path do UI gửi. UI chỉ gửi package IDs.
2. Yêu cầu UID root là 0. Kiểm tra manager, partition và cấu hình mount.
3. Chỉ nhận app người dùng đang bật, user 0, chưa có module; loại chính SysLeaf.
4. Kiểm tra package ID, đường dẫn `/data/app`, cùng thư mục APK và tên file an toàn. Chống trùng package và trùng tên split.
5. Giữ lock ở `/data/adb/.sysleaf-lock`; tạo staging riêng ngoài thư mục modules. Kiểm tra dung lượng.
6. So sánh danh sách `pm path --user 0` với inventory trước và sau khi copy. SHA-256 trước copy, trên bản sao và trên nguồn sau copy phải giống nhau.
7. Copy native libraries, sinh module.prop và permission denial XML, đặt owner 0:0, mode 0755/0644 và SELinux `system_file`.
8. Chỉ publish module sau khi toàn bộ selection đã stage thành công. EXIT/TERM trap dọn staging/lock và rollback các module vừa publish khi thao tác thất bại thông thường.
9. Dùng boot ID để nhận biết module đang chờ restart. Chỉ hiển thị **Đã systemize** khi Android trả `ApplicationInfo.FLAG_SYSTEM`; sau boot mà flag vẫn chưa có thì hiển thị **Chưa được mount**.

Gỡ module tạo marker `remove` cho manager xử lý ở lần boot sau; không uninstall app và không thay đổi dữ liệu riêng. Module của bên khác không bị thao tác.

## Phạm vi giao dịch

Mỗi module được stage đầy đủ trước khi chuyển vào thư mục manager. Rollback xử lý lỗi shell thông thường; mất nguồn/SIGKILL ở mức kernel giữa các lần publish không thể bảo đảm atomic cho toàn bộ batch. Sau sự cố, kiểm tra module trong manager trước khi chạy lại. Root shell có timeout để trap được chạy khi hết thời gian; nếu ROM không có toybox timeout, parent process vẫn có giới hạn chờ nhưng trạng thái cuối phải được kiểm tra lại.

Root commands được truyền qua stdin để batch lớn không vượt giới hạn argv của Linux. stdout/stderr được đọc song song, có giới hạn dung lượng. Flutter worker trả JSON lỗi có mã ổn định; UI dịch thông báo lỗi và có phần chi tiết để chẩn đoán.

Preferences được ghi bằng file tạm rồi rename trong Application files dir. FFI trả CString do Rust sở hữu; Dart luôn gọi `sysleaf_free` trong `finally`. Input do Dart sở hữu được giải phóng riêng.

## Mount và phân vùng

Module chứa `system/system_ext/…`, theo quy ước của Magisk và scanner Hybrid Mount. Các tệp nguồn module ở `/data` có thể ghi; việc mount không yêu cầu remount-RW phân vùng system_ext vật lý. Hybrid Mount cần kernel/ROM có backend được hỗ trợ và cấu hình cho phép real mount. SysLeaf không sửa cấu hình toàn cục của Hybrid Mount, không nạp kernel module và không tắt SELinux.

APatch và VFS không nằm trong phạm vi hỗ trợ hiện tại. Ngân hàng/mạng xã hội là heuristic có thể cập nhật tại `rust/src/categories.rs`; thông tin nhóm không ảnh hưởng quyền Android.

