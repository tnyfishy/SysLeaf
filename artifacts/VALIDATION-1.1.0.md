# Kết quả kiểm tra bản 1.1

Kiểm tra trong môi trường build Linux ngày 2026-10-07. Đây là kết quả tự động/local, không phải kiểm thử trên điện thoại root.

- `flutter analyze`: không có lỗi/cảnh báo.
- `flutter test`: **25 tests đạt**. Ngoài các luồng root/disable/uninstall hiện có, kiểm tra nội dung theo ảnh, chip nằm dưới tìm kiếm và không có checkmark, ba mục sort trạng thái trên màn hình 320×640, link Hybrid chỉ xuất hiện khi chưa sẵn sàng, About 1.1, lịch sử app đã gỡ và huỷ/xác nhận chuyển module ngân hàng.
- `cargo test --locked`: **17 tests đạt**. Shell giao dịch chạy trong thư mục tạm với lệnh root/SELinux/PackageManager giả; không thao tác lên Android thật.
- Cài module mới: ngân hàng vào `system/app/<package>` và không tạo XML priv-app; app khác giữ `system/system_ext/priv-app`. Xác minh base/split/native và metadata đích, dữ liệu riêng không bị thay đổi.
- Chuyển module ngân hàng cũ: giữ APK/split/native, marker disabled và dữ liệu riêng, bỏ XML của chính package ở đích cũ, giữ bản sao ngoài thư mục module và đánh dấu chờ reboot. Khi publish module thứ hai lỗi, cả hai module cũ được khôi phục và staging/lock được dọn.
- Script dọn bản sao được chạy với boot ID/mount giả: giữ bản sao trong cùng boot; giữ khi split APK tại đích sai; chỉ dọn bản sao của chính module sau boot khác khi tất cả APK khớp. Bản sao module còn tắt vẫn tồn tại.
- Kiểm tra mount prerequisites: ngoại lệ thiếu `system_ext/priv-app` dành cho ngân hàng không bỏ qua manager không hỗ trợ, thiếu Hybrid hoặc rule chặn mount.
- Lịch sử cục bộ: app bị Android quên được đánh dấu đã gỡ; reinstall thay thế metadata cũ; cache lỗi không bị ghi đè âm thầm. App đã gỡ không được chọn cho root action.
- Clippy host (`--all-targets --locked -- -D warnings`) và Android ARM64 (`cargo ndk -t arm64-v8a clippy --release --locked -- -D warnings`): đạt. Rustfmt và `git diff --check`: đạt.
- Build release **ARM64** và **universal ARMv7/ARM64/x86_64**: đạt. Version name `1.1.0`, version code `3`; About hiển thị `1.1`.
- Xác minh APK bằng `apksigner verify`, `zipalign -c -P 16 4`, `aapt dump badging` và đọc ELF program headers. Mỗi ABI có Flutter engine, Dart AOT và Rust core; ELF 64-bit có PT_LOAD alignment ít nhất 16KB.

APK local dùng debug key; checksum local trong `SHA256SUMS-1.1.0.txt`. GitHub Actions build/ký lại APK và tạo `SHA256SUMS.txt` cho asset release, nên checksum local không dùng để xác minh APK tải từ GitHub. Key debug của mỗi lần chạy Actions khác nhau; nếu Android báo chữ ký xung đột cần gỡ SysLeaf cũ trước khi cài mới. Module vẫn còn; lịch sử/tùy chọn riêng của SysLeaf bị xoá.

Ảnh trong `artifacts/screenshots` được render từ widget Flutter thật với dữ liệu giả chỉ trong tests. Emoji có thể thiếu glyph trong môi trường render Linux; Android dùng font emoji của ROM.

Chưa kiểm tra mount/reboot, disable/uninstall hoặc chuyển module trên điện thoại root thật. Cần đối chiếu [DEVICE_TESTING.md](../docs/DEVICE_TESTING.md), gồm Magisk, KernelSU + Hybrid Mount, đường dẫn APK sau boot, dữ liệu riêng, các module disabled và khôi phục khi thao tác bị ngắt. Lịch sử không truy lại được app đã bị Android quên trước lần SysLeaf nhìn thấy; systemize không bảo đảm vượt kiểm tra root/integrity của ngân hàng.
