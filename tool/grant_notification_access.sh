#!/bin/sh
# Cấp lại 2 quyền đọc thông báo cho app qua adb.
#
# Phải chạy lại sau MỖI lần cài đè app (flutter run / flutter install), vì
# Android thu hồi cả hai khi package được cài lại.
#
#   1. Notification access — không có thì app không nhận được thông báo nào.
#   2. RECEIVE_SENSITIVE_NOTIFICATIONS — Android 15 trở lên giấu nội dung
#      những thông báo bị coi là nhạy cảm (biến động số dư, OTP). Thiếu quyền
#      này thì thông báo MB Bank về app chỉ còn câu "Sensitive notification
#      content hidden", không mẫu bóc tách nào cứu được.
set -e

PKG=com.trustsoft.tingting
LISTENER="$PKG/notification.listener.service.NotificationListener"

adb shell appops set "$PKG" RECEIVE_SENSITIVE_NOTIFICATIONS allow

# Giữ nguyên các listener sẵn có: `cmd notification allow_listener` trên HyperOS
# ghi đè cả danh sách, đá văng listener của app khác (Xiaomi Barrage...).
CURRENT=$(adb shell settings get secure enabled_notification_listeners | tr -d '\r')
OTHERS=$(printf '%s' "$CURRENT" | tr ':' '\n' | grep -v -x -e "$LISTENER" -e null -e '' | paste -sd: -)

# Bind lại listener: hệ thống chỉ đọc appop lúc bind, nên nếu quyền nghe đã bật
# sẵn từ trước thì cấp appop suông không có tác dụng cho tới lần bind sau.
adb shell settings put secure enabled_notification_listeners "$OTHERS"
if [ -n "$OTHERS" ]; then
  adb shell settings put secure enabled_notification_listeners "$OTHERS:$LISTENER"
else
  adb shell settings put secure enabled_notification_listeners "$LISTENER"
fi

echo "notification listeners: $(adb shell settings get secure enabled_notification_listeners | tr -d '\r')"
echo "sensitive notifications: $(adb shell appops get "$PKG" RECEIVE_SENSITIVE_NOTIFICATIONS | tr -d '\r')"
