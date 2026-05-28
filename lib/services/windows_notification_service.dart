import 'dart:io';

class WindowsNotificationService {
  static final WindowsNotificationService _instance = WindowsNotificationService._();
  factory WindowsNotificationService() => _instance;
  WindowsNotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (!Platform.isWindows) return;
    _initialized = true;
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized || !Platform.isWindows) return;

    try {
      // Use PowerShell to show Windows toast notification
      final script = '''
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        \$template = @"
        <toast>
          <visual>
            <binding template="ToastGeneric">
              <text>$title</text>
              <text>$body</text>
            </binding>
          </visual>
        </toast>
"@

        \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        \$xml.LoadXml(\$template)
        \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("FileTransfer").Show(\$toast)
      ''';

      await Process.run('powershell', ['-Command', script]);
    } catch (e) {
      print('Windows notification failed: $e');
    }
  }

  Future<void> showFileNotification({
    required String title,
    required String body,
  }) async {
    await showMessageNotification(title: title, body: body);
  }

  Future<void> showConnectionRequestNotification({
    required String deviceName,
  }) async {
    await showMessageNotification(
      title: '连接请求',
      body: '$deviceName 请求连接到此设备',
    );
  }
}
