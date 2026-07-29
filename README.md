# Ting Ting

**Ghi sổ thu chi tự động từ thông báo ngân hàng.**

Mỗi lần tiền vào hoặc ra, ngân hàng đều bắn cho bạn một thông báo. Ting Ting đọc
chính những thông báo đó, bóc ra số tiền, số dư và nội dung chuyển khoản, rồi tự
ghi thành một dòng trong sổ. Bạn không phải mở app, không phải gõ lại con số nào
— cuối tháng mở lên là đã có sẵn báo cáo.

Toàn bộ dữ liệu nằm trong một file SQLite trên máy bạn. Không có tài khoản, không
có server, không có gì được gửi đi đâu.

---

## Có gì trong app

Bốn tab chính:

| Tab | Nội dung |
| --- | --- |
| **Thu chi** | Số dư hai ví, tổng thu–chi trong kỳ, danh sách giao dịch theo ngày, tìm kiếm và lọc theo khoảng ngày / nhóm / chiều tiền. |
| **Sổ nợ** | Ai đang nợ mình, mình đang nợ ai, lịch sử vay–trả với từng người. |
| **Báo cáo** | Chi theo nhóm, xu hướng 6 tháng, dự báo tháng này đang đi về đâu, so sánh với tháng trước. |
| **Ngân hàng** | Mỗi app gửi thông báo một dòng: bật/tắt ghi nhận, khai mẫu bóc tách riêng, xem thông báo nào chưa đọc ra được. |

### Bóc tách thông báo không cần hard-code từng ngân hàng

Mỗi nhà băng một format, và họ đổi format bất chợt. Nên bộ bóc tách mặc định
không nhắm vào tên ngân hàng nào cả — nó bám vào những thứ luôn có mặt: con số
kèm đơn vị tiền (`1.234.567 VND`, `50,000đ`), dấu `+`/`-`, nhãn `SD`/`Số dư`,
nhãn `ND`/`Nội dung`. Chiều tiền suy ra từ dấu, không có dấu thì suy từ từ khoá
(`ghi có`, `ghi nợ`, `thanh toán`…); không đủ manh mối thì app **gắn cờ "cần xem
lại"** thay vì đoán bừa.

Khi một ngân hàng nào đó vẫn không đọc nổi, bạn khai **mẫu riêng** cho app đó ở
tab Ngân hàng: nhãn hoặc regex cho từng trường, cố định chiều tiền, từ khoá
thu/chi riêng, điều kiện chỉ-nhận / bỏ-qua. Regex viết sai được báo đỏ ngay lúc
gõ, và nếu vẫn hỏng thì app quay về cách mặc định chứ không làm đứt luồng nhận
thông báo.

### Nguồn giao dịch tự hiện ra

Không phải khai trước tên package của từng ngân hàng. Thông báo nào bóc ra được
số tiền thì app gửi nó tự xuất hiện ở danh sách nguồn dưới dạng "chờ bật" — dùng
máy vài hôm là chúng lộ diện đủ.

### Phân loại

Bộ nhóm chi tiêu dựng sẵn có thể sửa, thêm, xoá tuỳ ý. Ngoài ra bạn tự đặt **quy
tắc**: nội dung chứa từ khoá nào thì vào nhóm nào, hoặc tự động loại khỏi báo
cáo. Quy tắc của bạn được xét trước bộ từ khoá mặc định, nên luôn đè được lên
máy đoán.

### Hai ví, và sổ nợ tách riêng

Tiền được theo dõi làm hai ví: **tài khoản** (số liệu tự lấy từ thông báo) và
**tiền mặt** (bạn tự nhập, hoặc sinh ra khi rút ATM). Số dư không lưu thành một
con số chép tay — sửa "số tiền đang có" sẽ ghi thêm đúng phần chênh lệch, nên
lịch sử luôn cộng ra được con số đang hiện.

Sổ nợ nằm ngoài Thu–Chi: bố mẹ chuyển tiền cho bạn không phải thu nhập, bạn trả
lại cũng không phải chi tiêu — nó chỉ làm số dư giữa hai bên thay đổi.

### Đối soát số dư — tìm giao dịch app đã bỏ lỡ

Đọc thông báo là cách ghi sổ không có gì đảm bảo: máy tắt nguồn, Android bóp
tiến trình nền, hệ thống giấu nội dung nhạy cảm — giao dịch biến mất khỏi sổ mà
không ai biết. Nhưng ngân hàng gửi kèm số dư sau mỗi giao dịch, nên chính các con
số đó tố cáo chỗ thiếu:

```
số dư sau = số dư trước + tổng các khoản đã ghi ở giữa
```

Lệch bao nhiêu là thiếu đúng bấy nhiêu tiền, và nó chắc chắn nằm trong khoảng
thời gian giữa hai giao dịch đó. Màn đối soát chỉ ra từng chỗ hở và cho bù vào
một khoản đúng bằng phần chênh — có gắn cờ "cần xem lại" để bạn đặt lại nhóm.

### Nhìn lại & nhắc nhở

Màn **Nhìn lại** không nói tiền đi đâu (đó là việc của Báo cáo) mà nói **cái gì
đã đổi**: tuần/tháng này tiêu hơn hay kém kỳ trước, nhóm nào đội lên mạnh nhất,
ngày nào nặng nhất, mấy ngày không tiêu gì. Kỳ trước được cắt đúng số ngày đã
trôi qua của kỳ này, nếu không thì tuần nào cũng "tiêu ít hơn tuần trước" cho tới
tận Chủ Nhật.

Kèm theo: lời nhắc sáng thứ Hai, thông báo mỗi giao dịch mới với nút bấm nhanh
(ghi chú, không tính, cho vay…), và một **widget ngoài màn hình chính Android**
hiện số đã chi tháng này.

### Sao lưu

Toàn bộ sổ sách xuất ra một file duy nhất, nạp lại theo hai kiểu: **gộp thêm**
(giữ nguyên dữ liệu đang có, chỉ bù phần thiếu — nạp lại nhiều lần không sinh bản
sao nhờ khoá chống trùng) hoặc **thay thế toàn bộ**. Cài đặt cũng đi theo file
sao lưu.

---

## Chạy thử

Yêu cầu: Flutter với Dart SDK `^3.12.2`, và một **máy/emulator Android** (tính
năng đọc thông báo là API riêng của Android).

```sh
flutter pub get
flutter run
```

Sau khi cài, app cần được cấp **quyền đọc thông báo** trong Cài đặt hệ thống.
Trên Android 15 trở lên còn cần thêm `RECEIVE_SENSITIVE_NOTIFICATIONS` — thiếu
quyền này, hệ thống thay nội dung thông báo ngân hàng bằng câu "Sensitive
notification content hidden" và không mẫu bóc tách nào cứu được. App phát hiện và
báo thẳng trường hợp này thay vì để bạn ngồi sửa regex.

Cấp cả hai quyền bằng adb:

```sh
sh tool/grant_notification_access.sh
```

> Phải chạy lại sau **mỗi** lần cài đè app (`flutter run` / `flutter install`) —
> Android thu hồi cả hai khi package được cài lại.

Chạy test:

```sh
flutter test
```

---

## Kiến trúc

```
lib/
├── core/          tiện ích thuần: khoảng ngày, tiền, chuẩn hoá chữ
├── models/        kiểu dữ liệu (Txn, Rule, Category, ParserProfile, …)
├── domain/        nghiệp vụ thuần, không phụ thuộc Flutter lẫn database:
│                  bóc tách thông báo, phân loại, dựng giao dịch,
│                  đối soát số dư, tổng kết kỳ, sao lưu
├── data/          SQLite: dao/ (truy vấn) + repositories/ (nghiệp vụ dữ liệu)
├── services/      cầu nối nền tảng: nghe thông báo, foreground service,
│                  thông báo đẩy, widget màn hình chính
└── ui/            màn hình + controllers/ (mỗi màn một controller)
```

Vài điểm đáng nói:

- **Tầng `domain/` không biết gì về database và Flutter**, nên toàn bộ phần khó
  nhất — bóc tách, đối soát, tổng kết — test được thẳng bằng `flutter test`.
- **`TxnFactory` là chỗ duy nhất** quyết định một giao dịch mới mang nhóm gì, có
  vào báo cáo không, có phải chuyển ví không. Service lẫn UI đều gọi vào đây.
- **Foreground service giữ một isolate riêng** để nghe thông báo. Không có nó,
  vuốt app khỏi recents là đứt luồng: plugin ôm `EventSink` của engine Flutter
  gắn với activity, activity chết thì hệ thống vẫn bắn broadcast nhưng không còn
  ai nghe. Đổi lại là một thông báo thường trực — Android bắt buộc, và tiện thể
  làm đèn báo app còn sống hay đã bị hệ thống giết.
- **Widget màn hình chính không tự tính gì**: launcher vẽ nó nên nó không mở được
  database của app. Dart tính sẵn từng dòng chữ rồi đẩy sang Kotlin, bên đó chỉ
  bơm vào `RemoteViews`.
- **Mọi thông báo thô đều được lưu lại** (màn Nhật ký), kể cả cái không bóc tách
  được — đó chính là dữ liệu để khai mẫu riêng cho ngân hàng chưa đọc nổi.

## Riêng tư

Không tài khoản, không đăng nhập, không đồng bộ đám mây, không analytics. Database
nằm trong vùng riêng của app trên máy bạn; đường duy nhất để dữ liệu ra ngoài là
bạn tự bấm xuất file sao lưu.
