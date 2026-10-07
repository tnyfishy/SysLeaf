# Kết quả kiểm tra bản 0.2.0

- `flutter analyze`: không có lỗi/cảnh báo.
- `flutter test`: 18 tests đạt. Luồng mới kiểm tra đa lựa chọn, app hệ thống, huỷ/xác nhận disable/uninstall, bản chụp danh sách review, cảnh báo Anh/Việt, lỗi một phần, root gate, timeout và màn hình 320×640.
- `cargo test`: 13 tests đạt. PackageManager giả kiểm tra user 0, preflight/lock, xử lý batch tiếp sau lỗi, kết quả Android thất bại dù exit 0, thành công giả khi trạng thái chưa thay đổi và lỗi truy vấn trạng thái. Không chạy lệnh pm thật trên máy build.
- Clippy host với `--all-targets --locked -- -D warnings`: đạt. Rustfmt và `git diff --check`: đạt.
- Build release ARM64 và universal (ARMv7/ARM64/x86_64): đạt. Version name `0.2.0`, version code `2`.
- Chữ ký APK và zip alignment 16KB: xác minh bằng `apksigner verify` và `zipalign -c -P 16 4`. Mỗi ABI có đủ Flutter engine, Dart AOT và Rust core; các ELF 64-bit có segment alignment ít nhất 16KB.
- APK local dùng debug key, là bản thử nghiệm. Checksum local nằm trong `SHA256SUMS-0.2.0.txt`; APK do GitHub Actions build có chữ ký/checksum riêng.
- Cấu hình GitHub Actions bỏ gói SDK lỗi thời `tools`; chỉ yêu cầu `platform-tools` trong bước setup. Workflow cũ dừng trước các bước compile vì Google không còn cung cấp gói `tools`.

Ảnh `disable_warning_vi.png`, `uninstall_warning_vi.png` và `apps_vi.png` được render từ widget Flutter thật với inventory giả chỉ trong tests. Chưa kiểm tra disable/uninstall/mount/reboot trên điện thoại root thật. Quy trình kiểm tra thực tế và khôi phục nằm trong [DEVICE_TESTING.md](../docs/DEVICE_TESTING.md).
