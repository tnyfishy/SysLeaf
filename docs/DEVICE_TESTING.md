# Kiểm tra trên thiết bị root

Môi trường build không gắn điện thoại root. Các bước sau là kiểm tra chấp nhận cần chạy trên thiết bị thực, không phải kết quả đã được xác minh.

## Magisk

1. Cài SysLeaf và một ứng dụng thử nghiệm có dữ liệu dễ kiểm tra (ví dụ ghi chú có nội dung đã lưu).
2. Từ chối yêu cầu su: chỉ màn hình yêu cầu root xuất hiện, không có tab Ứng dụng.
3. Cấp su, tải lại và kiểm tra tên/icon/số lượng app đúng với thiết bị.
4. Chọn app thử nghiệm; mở xác nhận rồi chọn **Khoan đã😐**. Không có module mới trong Magisk.
5. Xác nhận lại bằng **Vâng!😋**. Kiểm tra module `sysleaf_<package>` và đủ base/split APK. SysLeaf phải ghi **Chờ khởi động lại**.
6. Khởi động lại; app phải có `FLAG_SYSTEM`, dữ liệu đã lưu vẫn hiện và module ở trạng thái **Đã systemize**.
7. Nếu có ADB, đối chiếu với `adb shell su -c 'pm list packages -s com.example.app'` (thay mã gói thật).
8. Gỡ module từ SysLeaf rồi khởi động lại: app vẫn được cài, dữ liệu còn và không còn là system app do module này.

## KernelSU + Hybrid Mount

Chạy quy trình trên với Hybrid Mount đã bật và backend OverlayFS; lặp lại với backend Magic Mount nếu kernel hỗ trợ. Kiểm tra lần lượt: thiếu Hybrid Mount, module bị tắt, backend VFS, rule `ignore` — SysLeaf phải chặn tạo module và chỉ rõ điều kiện cần sửa.

KernelSU app profile phải cho phép root của SysLeaf và không chặn truy cập cần thiết vào danh sách app/module. Khởi động lại sau khi cài Hybrid Mount trước khi đánh giá mount.

## Những trường hợp cần đối chiếu

- App có base + nhiều split APK và app dùng native libraries.
- Chọn nhiều app; cập nhật hoặc uninstall một app trong lúc tạo module: thao tác phải thất bại hoặc phát hiện thay đổi và không báo thành công giả.
- `/data` thiếu dung lượng; lệnh copy/SELinux thất bại: module chưa hoàn tất không được mount ở boot sau.
- Mất quyền root khi đang mở app: refresh trở về root gate; hành động root tiếp theo không chạy bằng quyền user thường.
- Bật/tắt/gỡ module trong manager rồi mở lại SysLeaf; kiểm tra trạng thái phản ánh marker và FLAG_SYSTEM.
- Android 11 và Android 16, ARM64 (gồm thiết bị 16KB page size), ARMv7/x86_64 khi manager tương ứng hỗ trợ.
- UI tiếng Việt/Anh, dark mode hệ thống, pure black, màn hình có cutout và gesture navigation.

## Khôi phục

Trước hết tắt/gỡ đúng module **SysLeaf · tên ứng dụng** trong Magisk/KernelSU rồi reboot. Dữ liệu riêng và bản cài `/data/app` không bị SysLeaf xóa.

Nếu thao tác bị ngắt và app báo **OPERATION_BUSY** dù đã reboot, lock cũ có thể còn tồn tại. Chỉ sau khi reboot và khi không có thao tác SysLeaf đang chạy, có thể dọn lock rỗng bằng:

```bash
adb shell su -c 'rmdir /data/adb/.sysleaf-lock'
```

Nếu máy không boot vào Android, dùng cơ chế tắt module/recovery của trình quản lý root đang dùng. Các module cần loại bỏ có ID bắt đầu `sysleaf_`; không cần xóa `/data/user`, `/data/user_de` hoặc `/data/app` để gỡ systemize.

