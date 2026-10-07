class Strings {
  const Strings(this.language);
  final String language;
  String t(String key) {
    final value = _text[key];
    return value == null ? key : value[language == 'en' ? 1 : 0];
  }

  static const Map<String, List<String>> _text = {
    'removing_work': ['Đang lên lịch gỡ module…', 'Scheduling module removal…'],
    'rebooting': ['Đang khởi động lại…', 'Restarting…'],
    'busy_desc': [
      'Đang áp dụng thay đổi qua quyền su.',
      'Applying changes with su access.',
    ],
    'home': ['Trang chủ', 'Home'],
    'apps': ['Ứng dụng', 'Apps'],
    'settings': ['Cài đặt', 'Settings'],
    'reboot': ['Khởi động lại', 'Restart'],
    'subtitle': ['Không gian mới cho ứng dụng.', 'A new home for your apps.'],
    'hero': [
      'Ứng dụng của bạn.\nMột phần hệ thống.',
      'Your apps.\nPart of the system.',
    ],
    'hero_desc': [
      'Chọn ứng dụng yêu thích và đưa vào system_ext với module Magisk hoặc KernelSU.',
      'Give your favourite apps a home in system_ext with a Magisk or KernelSU module.',
    ],
    'choose_apps': ['Chọn ứng dụng', 'Choose apps'],
    'root_ready': ['Đã cấp quyền root', 'Root access granted'],
    'root_desc': [
      'Kết nối superuser đang hoạt động',
      'Superuser connection is active',
    ],
    'root_needed': ['Cần quyền superuser', 'Superuser access required'],
    'root_needed_desc': [
      'SysLeaf cần quyền su để đọc trạng thái hệ thống và tạo module. Hãy cấp quyền trong Magisk hoặc KernelSU.',
      'SysLeaf needs su access to read system status and create modules. Grant access in Magisk or KernelSU.',
    ],
    'root_loading': ['Đang yêu cầu quyền su…', 'Requesting su access…'],
    'grant_root': ['Cấp quyền root', 'Grant root access'],
    'root_retry': ['Thử lại', 'Try again'],
    'loading_apps': ['Đang đọc danh sách ứng dụng…', 'Reading installed apps…'],
    'available': ['Có thể chọn', 'Available'],
    'managed': ['Module của bạn', 'Your modules'],
    'pending': ['Chờ khởi động lại', 'Restart pending'],
    'overview': ['TỔNG QUAN', 'OVERVIEW'],
    'mount_engine': ['CƠ CHẾ MOUNT', 'MOUNT ENGINE'],
    'hybrid_desc': [
      'Overlay cho system_ext · KernelSU',
      'Overlay for system_ext · KernelSU',
    ],
    'magic_desc': ['Module systemless · Magisk', 'Systemless modules · Magisk'],
    'mount_ready': ['Sẵn sàng', 'Ready'],
    'mount_needed': ['Cần thiết lập', 'Setup needed'],
    'hybrid_required': [
      'Cài và bật Hybrid Mount, chọn OverlayFS hoặc Magic Mount trong cấu hình, rồi khởi động lại thiết bị.',
      'Install and enable Hybrid Mount, select OverlayFS or Magic Mount in its configuration, then restart the device.',
    ],
    'hybrid_link': ['Mở Hybrid Mount ↗', 'Open Hybrid Mount ↗'],
    'hybrid_magisk': [
      'Hybrid Mount upstream hỗ trợ KernelSU/APatch. Magisk dùng Magic Mount có sẵn.',
      'Upstream Hybrid Mount supports KernelSU/APatch. Magisk uses its built-in Magic Mount.',
    ],
    'how': ['SysLeaf hoạt động thế nào?', 'How does SysLeaf work?'],
    'step_1': ['01  Chọn ứng dụng', '01  Choose your apps'],
    'step_1_desc': [
      'Chọn một, nhiều ứng dụng hoặc một nhóm được nhận diện.',
      'Pick one app, several apps, or a detected group.',
    ],
    'step_2': ['02  Tạo module', '02  Create modules'],
    'step_2_desc': [
      'Sao chép APK, split APK và thư viện native vào module system_ext/priv-app.',
      'Copy APKs, split APKs and native libraries into a system_ext/priv-app module.',
    ],
    'step_3': ['03  Khởi động lại', '03  Restart'],
    'step_3_desc': [
      'Android nhận ứng dụng hệ thống sau khi module được mount thành công.',
      'Android recognises system apps after the module is mounted successfully.',
    ],
    'data_note': [
      'Dữ liệu, tài khoản và cài đặt ứng dụng được giữ ở /data. Module có thể gỡ trong trình quản lý root.',
      'App data, accounts and settings stay in /data. Modules can be removed in your root manager.',
    ],
    'search': ['Tìm tên hoặc tên gói…', 'Search name or package…'],
    'all': ['Tất cả', 'All'],
    'systemized': ['Hệ thống', 'System'],
    'social': ['Mạng xã hội', 'Social'],
    'banking': ['Ngân hàng', 'Banking'],
    'sort': ['Sắp xếp', 'Sort'],
    'by_name': ['Tên ứng dụng', 'App name'],
    'by_systemized': ['Ứng dụng đã systemize', 'Systemized apps'],
    'by_social': ['Mạng xã hội', 'Social apps'],
    'by_banking': ['Ngân hàng', 'Banking apps'],
    'presets': ['Chọn theo nhóm', 'Select a group'],
    'select_group': ['Chọn nhóm ứng dụng', 'Select an app group'],
    'preset_desc': [
      'Dựa trên mã gói đã biết và phân loại của Android. Danh sách chưa bao phủ mọi ứng dụng; hãy kiểm tra trước khi xác nhận.',
      'Based on known package IDs and Android categories. Detection is not exhaustive; review the list before confirming.',
    ],
    'group_detected': ['ứng dụng có thể chọn', 'eligible apps'],
    'nothing': ['Chưa có ứng dụng phù hợp', 'No matching apps'],
    'nothing_desc': [
      'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.',
      'Try another filter or search term.',
    ],
    'selected': ['đã chọn', 'selected'],
    'clear': ['Bỏ chọn', 'Clear'],
    'systemize': ['Systemize', 'Systemize'],
    'confirm_title': ['Đưa vào hệ thống?', 'Make these system apps?'],
    'confirm_question': [
      'Bạn muốn chọn (những) ứng dụng dưới đây làm ứng dụng hệ thống?',
      'Do you want to make the following app(s) system apps?',
    ],
    'confirm_note': [
      'SysLeaf sẽ tạo module cho các ứng dụng này. Bạn cần khởi động lại để áp dụng.',
      'SysLeaf will create modules for these apps. A restart is required to apply them.',
    ],
    'yes': ['Vâng!😋', 'Yes!😋'],
    'wait': ['Khoan đã😐', 'Wait😐'],
    'installing': ['Đang tạo module…', 'Creating modules…'],
    'installing_desc': [
      'Đang sao chép và kiểm tra APK. Hãy giữ ứng dụng mở đến khi hoàn tất.',
      'Copying and verifying APKs. Keep the app open until this finishes.',
    ],
    'success': ['Module đã sẵn sàng', 'Your modules are ready'],
    'success_desc': [
      'Khởi động lại để Android áp dụng thay đổi module.',
      'Restart so Android can apply the module changes.',
    ],
    'later': ['Để sau', 'Later'],
    'reboot_question': ['Khởi động lại thiết bị?', 'Restart your device?'],
    'reboot_desc': [
      'Thiết bị sẽ khởi động lại ngay. Hãy lưu công việc đang mở.',
      'Your device will restart now. Save any work you have open.',
    ],
    'cancel': ['Hủy', 'Cancel'],
    'remove': ['Gỡ module', 'Remove module'],
    'remove_desc': [
      'Module sẽ được gỡ sau khi khởi động lại. Bản ứng dụng người dùng và dữ liệu riêng được giữ nguyên.',
      'The module will be removed after restarting. Your user app and its private data are preserved.',
    ],
    'active': ['Đã systemize', 'Systemized'],
    'stock_system': ['App hệ thống', 'System app'],
    'disabled': ['Module bị tắt', 'Module disabled'],
    'removing': ['Đang chờ gỡ', 'Removal pending'],
    'mount_failed': ['Chưa được mount', 'Not mounted'],
    'not_enabled': ['Ứng dụng bị tắt', 'App disabled'],
    'appearance': ['Giao diện', 'Appearance'],
    'appearance_desc': [
      'Chọn không gian phù hợp với bạn',
      'Make this space your own',
    ],
    'theme_system': ['Theo hệ thống', 'Follow system'],
    'theme_light': ['Sáng', 'Light'],
    'theme_dark': ['Tối', 'Dark'],
    'theme_black': ['Đen tuyền', 'Pure black'],
    'language': ['Ngôn ngữ', 'Language'],
    'language_desc': ['Luôn cảm thấy quen thuộc', 'Feel right at home'],
    'system_info': ['Thông tin thiết bị', 'Device information'],
    'device': ['Thiết bị', 'Device'],
    'manager': ['Trình quản lý root', 'Root manager'],
    'partition': ['Đích mount', 'Mount target'],
    'about': ['Về SysLeaf', 'About SysLeaf'],
    'about_desc': [
      'Flutter + Rust · Material 3\nPhiên bản 0.1.0',
      'Flutter + Rust · Material 3\nVersion 0.1.0',
    ],
    'privacy': [
      'Danh sách ứng dụng được xử lý trên thiết bị. SysLeaf không gửi dữ liệu lên máy chủ.',
      'The app list is processed on your device. SysLeaf does not send data to a server.',
    ],
    'refresh': ['Làm mới', 'Refresh'],
    'error': ['Chưa thể hoàn tất', 'Could not complete'],
    'close': ['Đóng', 'Close'],
    'details': ['Chi tiết lỗi', 'Error details'],
    'err_ROOT_DENIED': [
      'Chưa có quyền su. Hãy cấp quyền trong trình quản lý root rồi thử lại.',
      'No su access. Grant permission in your root manager and try again.',
    ],
    'err_PARTITION_MISSING': [
      'Thiết bị không có /system_ext/priv-app. SysLeaf cần phân vùng này để hoạt động.',
      'This device has no /system_ext/priv-app. SysLeaf requires this partition.',
    ],
    'err_MANAGER_UNSUPPORTED': [
      'Cần Magisk hoặc KernelSU để quản lý module.',
      'Magisk or KernelSU is required to manage modules.',
    ],
    'err_HYBRID_REQUIRED': [
      'KernelSU cần Hybrid Mount đang bật với chế độ OverlayFS hoặc Magic Mount.',
      'KernelSU needs enabled Hybrid Mount using OverlayFS or Magic Mount.',
    ],
    'err_HYBRID_RULE_BLOCKED': [
      'Một quy tắc Hybrid Mount đang bỏ qua module SysLeaf hoặc dùng VFS. Chọn OverlayFS/Magic Mount cho module này.',
      'A Hybrid Mount rule ignores a SysLeaf module or uses VFS. Select OverlayFS/Magic Mount for that module.',
    ],
    'err_PRIMARY_USER_REQUIRED': [
      'Cài SysLeaf trong hồ sơ chủ thiết bị (user 0).',
      'Install SysLeaf in the device owner profile (user 0).',
    ],
    'err_APP_CHANGED': [
      'Ứng dụng vừa thay đổi hoặc được cập nhật. Làm mới danh sách rồi chọn lại.',
      'An app changed or was updated. Refresh the list and select it again.',
    ],
    'err_MODULE_EXISTS': [
      'Ứng dụng đã có module. Làm mới để xem trạng thái hiện tại.',
      'This app already has a module. Refresh to see its current state.',
    ],
    'err_NO_SPACE': [
      'Không đủ dung lượng trong /data để tạo module.',
      'Not enough space in /data to create modules.',
    ],
    'err_INVALID_SELECTION': [
      'Có thể chọn tối đa 100 ứng dụng trong một lần.',
      'Select up to 100 apps per operation.',
    ],
    'err_OPERATION_BUSY': [
      'Một thao tác khác đang chạy. Đợi hoàn tất rồi thử lại.',
      'Another operation is running. Wait for it to finish and try again.',
    ],
    'err_SELINUX_FAILED': [
      'Không đặt được nhãn SELinux. Module chưa được áp dụng.',
      'Could not apply SELinux labels. The modules have not been applied.',
    ],
    'err_TIMEOUT': [
      'Thao tác su đã hết thời gian chờ. Làm mới danh sách và kiểm tra trình quản lý module trước khi thử lại.',
      'The su operation timed out. Refresh and check your module manager before retrying.',
    ],
    'err_default': [
      'Thao tác chưa hoàn tất. Bạn có thể làm mới và thử lại.',
      'The operation did not complete. Refresh and try again.',
    ],
  };
  String error(String? code) =>
      _text.containsKey('err_$code') ? t('err_$code') : t('err_default');
}
