# SideScreen

Ứng dụng Flutter cho Android/iPhone: khi mở app và có màn hình ngoài được hệ điều hành cấp qua USB-C/HDMI, app mở một không gian làm việc riêng trên màn hình đó. Điện thoại là bàn điều khiển.

## Bản 0.9 đã có

- Bấm biểu tượng Dock của app đang ở trước để thu nhỏ; bấm lại để khôi phục. App phía sau được đưa lên trước; app đã đóng được mở lại. Cả chuột thật và chuột ảo dùng cùng quy tắc.
- Nút đóng cửa sổ phản hồi ngay, không chờ nhận diện nhấp đúp tiêu đề. Điện thoại có nút **✕** trực tiếp; iOS vẽ thêm bộ nút thu nhỏ/khôi phục/đóng trên lớp chrome riêng của cửa sổ đang chọn. Ghi chú ở màn hình ngoài không nhận bàn phím hay tạo lớp chặn chuột native.
- Trình duyệt tách lệnh chuyển trang của người dùng khỏi URL chuyển hướng được đồng bộ về: cập nhật cửa sổ/con trỏ không tải lại URL cũ. Các liên kết Google thông thường dùng điều hướng của website. Tải lỗi có nút **Thử lại**, trang quá 30 giây có hướng dẫn tải lại, giữ WebView để không làm mất bề mặt native khi thử lại.

- Cửa sổ đang chọn nằm trên cùng; ghi chú bị che không vẽ nổi lên trình duyệt, nhưng vẫn giữ nội dung khi chuyển app. Cửa sổ khôi phục vẫn có thể chồng lên nhau.
- Thanh trên desktop còn 28 điểm, tiêu đề cửa sổ 36 điểm và thanh địa chỉ 44 điểm để dành thêm chỗ cho trang web.
- Nút **Thu nhỏ video** luôn có ở bên phải thanh địa chỉ, nhận cả chuột ảo từ điện thoại. iOS còn vẽ nút này trên lớp chrome riêng và dùng API WebKit công khai để đóng trình phát native khi nhận lệnh thoát.
- Bấm ô địa chỉ bằng chuột ảo tự mở ô nhập trên điện thoại; chữ đang nhập và con trỏ nháy đồng bộ lên màn hình ngoài. Bàn phím vẫn thuộc điện thoại.

- Hai giao diện độc lập: điều khiển trên điện thoại và desktop trên màn hình ngoài.
- iOS đặt taskbar và con trỏ trong một UIWindow trong suốt riêng, cao hơn cửa sổ nội dung/native fullscreen, không nhận chạm hay lấy quyền bàn phím của điện thoại. Cần build lại cả Swift và Dart của bản 0.9; thay đổi iOS chưa được xác nhận trên máy thật trong môi trường Windows này.
- Con trỏ nhỏ 16×20, màu mint có mặt cười; có chỉnh kích thước trong Tùy chỉnh, lưu cùng phiên.
- Di chuột chỉ gửi tọa độ qua bridge mới; không gửi lại toàn bộ ghi chú/cửa sổ hay dựng lại nội dung các app trong từng lần di chuyển. Bridge cũ tiếp tục dùng snapshot đầy đủ.
- Tự kiểm tra màn hình lúc mở app và theo dõi cắm/rút trong lúc chạy.
- Ba ứng dụng trong desktop: **Ghi chú**, **Trình duyệt** và **Bắt đầu**.
- Kéo, đổi kích thước, thu nhỏ, phóng to, đóng và mở lại cửa sổ.
- Chuyển động spring lấy cảm hứng macOS: mở cửa sổ nhẹ từ gần kích thước thật, thu nhỏ/khôi phục về Dock, xếp cạnh nhau và phóng to bằng transform; giữ nội dung khi thu nhỏ. Tôn trọng cài đặt giảm chuyển động của hệ thống.
- Dock cỡ vừa 320×72 điểm giao diện, biểu tượng 42 điểm, nền hoàn toàn trong suốt, nằm giữa và cách đáy 8 điểm mặc định. Kích thước và khoảng đáy giữ nhất quán trên Full HD, 16:10, ultrawide và 4K. Bản cũ được đặt lại khoảng đáy một lần; sau đó vẫn có thể tùy chỉnh để tránh màn hình bị cắt mép.
- Cửa sổ mới mở phóng to trong vùng làm việc, chừa Dock và thanh trên. Bấm **Khôi phục** để kéo/resize và chồng các cửa sổ; mở/kích hoạt/đóng app không tự chia ô hay đổi kích thước app khác. Chỉ xếp cạnh nhau khi chủ động chọn lệnh hoặc phím tắt. Phiên cũ chuyển sang chế độ phóng to một lần khi nâng cấp.
- Nút **Khôi phục desktop** nâng taskbar vào sâu hơn và phóng to cửa sổ đang chọn. Cài đặt có **Viền an toàn dưới màn hình** từ 4–96 điểm giao diện cho màn hình/cáp bị cắt mép.
- Kết nối và xuất hình thành công tự chuyển điện thoại sang bàn di chuột toàn màn hình, kèm ô nhập đang sẵn sàng nhận bàn phím vật lý. Nút bàn phím bật/tắt bàn phím hệ thống; có phím tắt, đổi app và nhập địa chỉ. Rút màn hình trở về bảng điều khiển. Menu **Điều khiển → Về bảng điều khiển** mở lại cài đặt mà không tự giành màn hình cho đến lần kết nối tiếp theo.
- Bàn di chuột nhận hover của chuột không cần nhấn, click, kéo và cuộn, cùng các thao tác vuốt/chạm/giữ-kéo. Trên iPhone, hover còn phụ thuộc sự kiện mà iOS/AssistiveTouch gửi cho app; không khẳng định có thể đọc chuyển động chuột khi hệ thống không cung cấp.
- Chế độ **Chuột & bàn phím** trên điện thoại: vùng điều khiển tuyệt đối ánh xạ sang desktop, nhận hover/click/drag/cuộn khi hệ điều hành gửi sự kiện; nhập ghi chú và địa chỉ bằng bàn phím vật lý, có phím tắt.
- Trình duyệt có thanh địa chỉ/tìm kiếm, lùi/tiến, tải lại, trang chủ và trang HTML thử tương tác không cần mạng. Android/iOS dùng WebView; bản web dùng iframe.
- Tìm kiếm mặc định bằng Google. Google trên bản web có nút mở tab riêng, tránh khung nhúng bị chặn; trên app dùng WebView.
- Trình duyệt Android/iOS yêu cầu website desktop bằng user agent giữ phiên bản engine của thiết bị. Liên kết thông thường và popup được đưa về cùng WebView; các liên kết mở app YouTube/Facebook và Android intent có địa chỉ web được chuyển sang HTTPS. Scheme app khác bị chặn, không tự mở ứng dụng ngoài. iOS bật phát video inline. Luồng này vẫn cần xác nhận trên iPhone thật.
- Video/trình phát được phóng lớn trong vùng trình duyệt để giữ Dock, con trỏ và tọa độ điều khiển. Hỗ trợ nút fullscreen YouTube, Fullscreen API và lối vào fullscreen video WebKit thông dụng; Escape, nút ✕ hoặc menu **Thoát video phóng lớn** để thoát. Rê chuột ảo được chuyển thành hover trong WebView với giới hạn khoảng 30 lần/giây, không dựng lại cửa sổ theo từng chuyển động. Các trình phát/iframe khác nguồn có cơ chế riêng vẫn cần kiểm tra theo website.
- YouTube trên bản web: trang chủ/tìm kiếm/kênh mở bằng nút tab riêng; liên kết video watch/youtu.be/shorts/live dùng trình phát nhúng chính thức, giữ mốc thời gian. Google/Facebook có trang giải thích và nút mở tab riêng khi xem thử trên web. Bản web không vượt qua giới hạn iframe của website.
- Mặc định phủ kín màn hình ngoài: bố cục thay đổi theo tỷ lệ màn hình, giữ hình ảnh và chữ đúng tỷ lệ. Có thể tắt trong Cài đặt → Phủ kín màn hình ngoài để giữ bố cục 16:10. Bản xem thử có nút Toàn màn hình.
- Ngôn ngữ nhập theo bàn phím hệ thống; có gợi ý tiếng Việt, Anh, Nhật, Hàn, Trung cho bàn phím Android hỗ trợ. iPhone đổi bộ gõ bằng phím 🌐 của bàn phím đã cài. Giữ vùng ghép dấu và vị trí con trỏ khi đồng bộ ghi chú.
- Tab **Trình duyệt** trên điện thoại gửi địa chỉ, cuộn trang và gửi chữ vào ô nhập đã chọn trên trang.
- Touchpad: vuốt để di chuột, chạm để chọn, giữ rồi vuốt để kéo. Có công tắc kéo và nút đưa con trỏ về giữa.
- Bàn phím điện thoại nhập trực tiếp vào ghi chú; ghi chú và vị trí cửa sổ đồng bộ giữa hai giao diện.
- Ba hình nền, điều chỉnh tốc độ con trỏ và đặt lại bố cục mà giữ ghi chú.
- Lưu phiên trên Android/iOS, khôi phục khi mở lại app hoặc cắm lại màn hình.
- Chế độ xem thử trong app và trên web, không báo giả rằng đã có màn hình vật lý.
- Giao diện tiếng Việt, font đóng gói sẵn; không cần tài khoản, backend hoặc mạng cho tính năng chính.

Các cửa sổ là thành phần của SideScreen. Bản này không chạy phần mềm Windows hoặc mở ứng dụng khác trong desktop.

## Chạy dự án

Cần Flutter stable có Dart 3.10 trở lên. Dự án được xây dựng và kiểm tra với **Flutter 3.47.8 / Dart 3.13.7**.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Xem thử giao diện trên máy tính:

```sh
flutter run -d chrome
```

Web chỉ dùng để thử giao diện, kéo cửa sổ và đồng bộ nội dung trong cùng phiên. Web không dùng native bridge để xuất màn hình có dây và không lưu dữ liệu sau khi tải lại trang.

Trong desktop, bấm biểu tượng quả địa cầu trên taskbar để mở **Trình duyệt**. Chọn **Trang thử tương tác** để thử JavaScript, nhập chữ và cuộn ngay cả khi không có mạng. Trên bản web, một số website chặn nhúng bằng CSP/X-Frame-Options: dùng **Mở tab ngoài** trong chân cửa sổ. Lịch sử trên web theo các địa chỉ nhập từ thanh địa chỉ; liên kết điều hướng bên trong website khác nguồn không thể được đọc lại do chính sách trình duyệt. Trên Android/iOS, website mở bằng WebView của hệ điều hành.

## Android

```sh
flutter build apk --debug
```

APK cài thử: `build/app/outputs/flutter-apk/app-debug.apk`. Đây là bản debug ký bằng khóa phát triển; cấu hình khóa phát hành riêng trước khi đưa lên cửa hàng.

Bản ARM64 0.9: `artifacts/SideScreen-0.9.0-arm64.apk` (tạo cục bộ khi build, không lưu APK trong Git).

Trên Windows, có thể dùng `scripts\build_android.cmd debug` để tự tìm Java đi kèm Android Studio. Bỏ `debug` để build APK release dành cho Android ARM64; bản release này vẫn dùng khóa phát triển của dự án.

Điện thoại cần hỗ trợ xuất video qua USB-C/DisplayPort hoặc adapter tương ứng. Dùng cáp có hỗ trợ video, chọn đúng nguồn vào trên màn hình, rồi mở app và giữ app ở phía trước. Không phải mọi điện thoại có USB-C đều hỗ trợ xuất hình.

Kiểm tra luồng màn hình phụ trong Android Emulator:

1. Chạy app trên emulator.
2. Mở Developer options → Simulate secondary displays → chọn 1280×800.
3. App tự tạo desktop trên màn hình mô phỏng. Điện thoại vẫn hiển thị bảng điều khiển.
4. Thử nhập ghi chú, đổi hình nền, tắt màn hình mô phỏng rồi bật lại.

Màn hình mô phỏng kiểm tra native bridge và vòng đời hiển thị; kiểm tra cáp/độ phân giải/thiết bị thực vẫn cần máy thật. Trên một số hệ điều hành, cắm màn hình khi app đã chạy có thể bị chặn mở tự động: thử nút kiểm tra lại kết nối, hoặc đóng rồi mở lại app khi màn hình vẫn đang cắm. App không báo đã hiển thị nếu hệ điều hành từ chối.

## iPhone / iOS

Build trên **macOS với Xcode 27 SDK trở lên**, vì mã có tích hợp scene accessory mới của iOS 27. Deployment target là iOS 15.

```sh
flutter pub get
flutter build ios --no-codesign
open ios/Runner.xcworkspace
```

Chọn Team trong Signing & Capabilities của Runner, chọn iPhone thật rồi Run. Không cần cấp quyền USB hoặc mạng nội bộ cho tính năng xuất hình này.

- iOS 15–26: external-display scene được khai báo trong `Info.plist` và hệ thống cấp khi có màn hình phù hợp.
- iOS 27+: đăng ký `UISceneAccessory.externalNonInteractive` trên giao diện chính. Hệ thống quyết định lúc tạo/hủy scene.
- Màn hình ngoài dùng `windowExternalDisplayNonInteractive`: điện thoại điều khiển các cửa sổ và nhập chữ. Không giả định màn hình ngoài trên iPhone nhận chuột/bàn phím như desktop của iPad.
- Cần đúng mẫu iPhone, cáp và adapter hỗ trợ video; chỉ có cổng USB-C là chưa đủ.
- Mã iOS chưa được compile/chạy trên Mac trong môi trường phát triển Windows hiện tại.

### Chuột và bàn phím Bluetooth trên iPhone

1. Bật **Cài đặt → Trợ năng → Cảm ứng → AssistiveTouch**; ghép chuột trong **Thiết bị → Thiết bị Bluetooth** theo [hướng dẫn Apple](https://support.apple.com/en-ie/111775). Ghép bàn phím trong Bluetooth của iPhone.
2. Mở SideScreen trên điện thoại → **Chuột & bàn phím**. Bấm/kéo trên sơ đồ cửa sổ để đưa thao tác sang desktop ngoài. Sơ đồ dùng cùng vị trí cửa sổ và taskbar với màn hình ngoài.
3. Chọn Ghi chú rồi nhập ở ô bên dưới bằng bàn phím Bluetooth. Với trình duyệt, dùng ô địa chỉ hoặc ô gửi chữ vào trường đã chọn trên trang.
4. Phím tắt Ctrl/⌘ + 1/2/3 mở Ghi chú/Trình duyệt/Bắt đầu; Ctrl/⌘ + L chọn địa chỉ; Ctrl/⌘ + W đóng; Ctrl/⌘ + M thu nhỏ; Ctrl/⌘ + Shift + T xếp cạnh nhau; Alt + Tab đổi cửa sổ.

iPhone cấp external scene không tương tác trực tiếp: thiết bị nhập vẫn được nhận trên điện thoại và chuyển thao tác qua bridge. AssistiveTouch có thể gửi thao tác như cảm ứng, không gửi hover/raw mouse; khi đó dùng bấm/giữ-kéo trên sơ đồ. Bản này không biến iPhone thành hệ điều hành desktop với con trỏ Bluetooth tự do trên màn hình ngoài. Chưa kiểm tra với chuột/bàn phím Bluetooth thật và iPhone 15 trong môi trường này.

## Kiến trúc

```text
Flutter engine chính (điện thoại)
  WorkspaceController: trạng thái duy nhất của phiên
  ControllerPage: touchpad, bàn phím, xem trước
            │
     MethodChannel dev.sidescreen/display
            │
  Kotlin / Swift: màn hình, vòng đời, lưu phiên, chuyển tiếp
            │
Flutter engine phụ (externalDisplayMain)
  DesktopView: nhận snapshot, gửi action về engine chính
```

Flutter engine phụ không sửa một bản dữ liệu riêng: thao tác từ nó được chuyển về điện thoại, sau đó điện thoại phát snapshot mới. Các isolate không chia sẻ trực tiếp biến Dart.

| Tệp | Vai trò |
|---|---|
| `lib/domain/workspace.dart` | Trạng thái, cửa sổ, hit testing của con trỏ, snapshot có phiên bản |
| `lib/platform/display_bridge.dart` | Giao tiếp Dart với native, fallback xem thử khi thiếu plugin |
| `lib/app.dart` | Đồng bộ hai engine, gộp cập nhật theo 16 ms, lưu dữ liệu sau 500 ms |
| `lib/ui/controller_page.dart` | Giao diện điện thoại và bố cục xem thử rộng |
| `lib/ui/desktop.dart` | Desktop, cửa sổ, ghi chú, dock và hình nền |
| `lib/ui/window_motion.dart` | Chuyển động cửa sổ, giữ cây widget khi thu nhỏ |
| `lib/ui/desktop_dock.dart` | Taskbar, hover bằng chuột/con trỏ, nhãn và hiệu ứng mở app |
| `lib/ui/desktop_viewport.dart` | Báo kích thước thực của vùng hiển thị, độc lập với chiều xoay điện thoại |
| `lib/ui/keyboard_preferences.dart` | Ngôn ngữ nhập và đồng bộ văn bản giữ trạng thái IME |
| `lib/ui/hardware_controller_page.dart` | Điều khiển bằng chuột/AssistiveTouch, bàn phím vật lý và phím tắt trên điện thoại |
| `lib/ui/desktop_motion.dart` | Spring có damping cho mở/đóng và bố trí cửa sổ |
| `lib/ui/cute_cursor.dart` | Con trỏ vector nhỏ và tùy chỉnh kích thước |
| `lib/ui/browser/` | WebView native, iframe web, điều khiển trên điện thoại và HTML demo |
| `android/app/src/main/kotlin/dev/sidescreen/side_screen/ExternalDisplayCoordinator.kt` | `DisplayManager`, `Presentation`, tạo/hủy engine phụ, SharedPreferences |
| `ios/Runner/AppDelegate.swift` | Bridge, scene accessory, engine phụ, UserDefaults |
| `ios/Runner/SceneDelegate.swift` | Vòng đời màn hình điện thoại và màn hình ngoài |

### Hợp đồng native bridge

Mỗi engine có cùng tên channel trên binary messenger riêng.

| Hướng | Method | Dữ liệu |
|---|---|---|
| Dart → native | `initialize` | Trả `{status, state}` |
| Chính → native | `refresh` | Kiểm tra lại kết nối |
| Chính → native → phụ | `publishState` / `stateChanged` | Snapshot `schemaVersion: 1` |
| Chính → native | `saveState` | Lưu snapshot JSON trên thiết bị |
| Phụ → native → chính | `dispatchAction` / `action` | Thao tác `{type, ...}` |
| Native → chính | `displayChanged` | Kết nối, trạng thái hiển thị, tên và kích thước màn hình |
| Chính → native → phụ | `publishPointer` / `pointerChanged` | Chỉ `{cursorX, cursorY}`, khi host báo `supportsPointerUpdates` |

Chỉ cập nhật có thay đổi nội dung/bố cục mới đặt lịch lưu; di con trỏ thông thường không ghi đĩa liên tục. Khi app rời foreground, app yêu cầu lưu ngay. Force-kill trong khoảng lưu 500 ms vẫn có thể mất thao tác cuối.

Lịch sử địa chỉ trình duyệt được lưu cùng phiên. Lệnh nhập chữ vào trang chỉ truyền trực tiếp giữa hai engine, không được đưa vào snapshot lưu trên đĩa của SideScreen. Website/WebView vẫn có thể có cơ chế lưu riêng.

## Giới hạn của MVP

- Một màn hình ngoài; khi có nhiều màn hình Android phù hợp, dùng màn hình có ID nhỏ nhất.
- Desktop mặc định có chiều cao logic 900 và chiều rộng theo tỷ lệ màn hình (hỗ trợ tỷ lệ 0,6–4,0); co đồng đều để phủ kín vùng hệ điều hành cấp. Chế độ giữ tỷ lệ dùng bố cục 1440×900 và có thể có viền. Cài đặt trên màn hình/cáp vẫn có thể tạo viền bên ngoài vùng mà app được cấp.
- Ghi chú tối đa 50.000 đơn vị UTF-16; chưa có nhiều tài liệu, hệ thống tệp hay đồng bộ đám mây.
- Touchpad điều khiển con trỏ, dock, thanh tiêu đề, góc đổi kích thước và bấm trong nội dung WebView. Dùng tab Bàn phím để chỉnh ghi chú, tab Trình duyệt để cuộn/gửi chữ vào trang. Con trỏ ảo trên web chỉ điều khiển nội dung trang demo đi kèm; website khác nguồn dùng chuột trực tiếp hoặc mở tab ngoài.
- Giao diện desktop dừng hiển thị khi app Android vào nền và được tạo lại khi quay lại. Phiên làm việc được giữ.
- Khả năng tương thích màn hình phụ phụ thuộc hệ điều hành và nhà sản xuất; cần kiểm tra thêm trên phần cứng mục tiêu.
- Khi Android không cho phép mở tự động lúc hot-plug, dùng nút thử lại hoặc mở lại app với màn hình đã kết nối. Số lần tự thử lại có giới hạn để không tạo vòng lặp mở màn hình.

## Kiểm tra

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
flutter build apk --debug
```

50 kiểm thử bao gồm giới hạn di chuyển/resize, kéo qua touchpad, hit testing của dock/nút cửa sổ, chuyển động đóng/mở/phóng to, không dựng lại nội dung trong từng frame animation, hover chuột/con trỏ ảo, giảm chuyển động, giữ ô địa chỉ khi thu nhỏ, tìm Google, định tuyến liên kết YouTube và kiểm tra địa chỉ, không lưu lệnh nhập chữ vào trang, khôi phục snapshot cũ, mô hình engine phụ, giữ vùng ghép dấu tiếng Việt, gợi ý ngôn ngữ, phủ kín màn hình 1920×1080/2560×1600, bố cục ultrawide và bố cục điện thoại 320/390/1024/1440 px.

Kiểm tra vòng đời native trên một emulator dùng riêng cho kiểm thử, sau khi build APK debug:

```sh
python scripts/android_smoke_test.py --adb <path-to-adb> --serial emulator-5580
```

Script cần Pillow, từ chối chạy với serial của thiết bị thật, khôi phục cài đặt màn hình mô phỏng sau kiểm tra và ghi rõ nếu hệ điều hành yêu cầu mở lại app sau hot-plug. Mặc định dùng `1280x800/160,own_content_only`, tức màn hình riêng cho nội dung trình chiếu. Có thể truyền `--display-mode 1280x800/160` để kiểm tra chế độ desktop mô phỏng của hệ điều hành. Script kiểm tra ảnh từ màn hình native đã vẽ nội dung, không chỉ kiểm tra cửa sổ đã tồn tại.

Các font Be Vietnam Pro được phân phối theo SIL Open Font License trong `assets/fonts/OFL.txt`. Icon được tạo từ các khối hình học bằng `scripts/generate_icons.py`; script cần Pillow nếu muốn tạo lại icon.

Tài liệu nền tảng:

- [Flutter multiple engines](https://docs.flutter.dev/add-to-app/multiple-flutters)
- [Android Presentation](https://developer.android.com/reference/android/app/Presentation)
- [Apple external-display scenes](https://developer.apple.com/documentation/uikit/presenting-content-on-a-connected-display)
- [Apple overscan compensation](https://developer.apple.com/documentation/uikit/uiscreen/overscancompensation-swift.enum/none)
- [Flutter IME language hints (Android)](https://api.flutter.dev/flutter/material/TextField/hintLocales.html)
- [Flutter custom scene lifecycle forwarding](https://docs.flutter.dev/add-to-app/ios/add-flutter-screen#if-you-cant-subclass-flutterscenedelegate)
- [YouTube embedded player](https://developers.google.com/youtube/player_parameters)
