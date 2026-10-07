import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';

class AlarmService {
  static Future<int> schedule({
    required DateTime classStart,
    required String subject,
    required String room,
    required String teacher,
  }) async {
    final ringAt = classStart.subtract(const Duration(minutes: 2));

    if (ringAt.isBefore(DateTime.now())) return -1;

    final id = classStart.millisecondsSinceEpoch ~/ 60000;

    final settings = AlarmSettings(
      id: id,
      dateTime: ringAt,
      assetAudioPath: 'assets/bell.mp3',
      loopAudio: false,
      vibrate: true,
      warningNotificationOnKill: false,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 3),
      ),
      notificationSettings: NotificationSettings(
        title: 'Next: $subject',
        body: '$room • $teacher',
        stopButton: 'Stop',
      ),
    );

    await Alarm.set(alarmSettings: settings);
    return id;
  }

  static Future<void> cancel(int id) async {
    if (id >= 0) await Alarm.stop(id);
  }

  static Future<void> cancelAll() async {
    final alarms = await Alarm.getAlarms();
    for (final a in alarms) {
      await Alarm.stop(a.id);
    }
  }
}