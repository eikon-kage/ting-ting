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

# Both listeners the app declares, and both have to be on.
#
#   - The plugin's one carries notifications to Dart live, but only while a
#     Flutter engine is running.
#   - BankNotificationListener is bound by the system and appends to a queue on
#     disk, which is the only thing that survives HyperOS killing the process on
#     a recents swipe. Granting just the first one leaves capture looking healthy
#     — service up, listener bound — right up until the swipe, and every message
#     after it is lost with nothing on screen saying so.
PLUGIN_LISTENER="$PKG/notification.listener.service.NotificationListener"
OWN_LISTENER="$PKG/$PKG.BankNotificationListener"

adb shell appops set "$PKG" RECEIVE_SENSITIVE_NOTIFICATIONS allow

# Giữ nguyên các listener sẵn có: `cmd notification allow_listener` trên HyperOS
# ghi đè cả danh sách, đá văng listener của app khác (Xiaomi Barrage...).
CURRENT=$(adb shell settings get secure enabled_notification_listeners | tr -d '\r')
OTHERS=$(printf '%s' "$CURRENT" | tr ':' '\n' \
  | grep -v -x -e "$PLUGIN_LISTENER" -e "$OWN_LISTENER" -e null -e '' | paste -sd: -)

OURS="$PLUGIN_LISTENER:$OWN_LISTENER"
if [ -n "$OTHERS" ]; then
  WANTED="$OTHERS:$OURS"
else
  WANTED="$OURS"
fi

# Bind lại listener: hệ thống chỉ đọc appop lúc bind, nên nếu quyền nghe đã bật
# sẵn từ trước thì cấp appop suông không có tác dụng cho tới lần bind sau.
adb shell settings put secure enabled_notification_listeners "$OTHERS"
adb shell settings put secure enabled_notification_listeners "$WANTED"

# Writing the setting is not enough on its own. A component added that way lands
# in the allowed list and stays there, unbound: it never appears under "Live
# notification listeners" and never receives a single notification. Only
# `allow_listener` makes the system actually bind it. The setting write above is
# still what keeps other apps' listeners in the list, so both steps are needed.
adb shell cmd notification allow_listener "$PLUGIN_LISTENER"
adb shell cmd notification allow_listener "$OWN_LISTENER"

# Say plainly whether both ended up bound, because everything upstream of this
# can succeed while capture is still dead.
LIVE=$(adb shell dumpsys notification | sed -n '/Live notification listeners/,/Snoozed/p' | tr -d '\r')
for c in "$PLUGIN_LISTENER" "$OWN_LISTENER"; do
  if printf '%s' "$LIVE" | grep -q "${c%%/*}/${c#*/}"; then
    echo "bound: $c"
  else
    echo "NOT BOUND: $c — bật tay trong Cài đặt > Thông báo > Quyền đọc thông báo"
  fi
done

echo "notification listeners: $(adb shell settings get secure enabled_notification_listeners | tr -d '\r')"
echo "sensitive notifications: $(adb shell appops get "$PKG" RECEIVE_SENSITIVE_NOTIFICATIONS | tr -d '\r')"
