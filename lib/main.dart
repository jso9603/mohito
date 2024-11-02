import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone 초기화
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));  // 예: 한국 시간대

  // 로컬 알림 초기화 설정
  await initializeNotifications();

  // 알림 권한 요청
  if (Platform.isAndroid) {
    var androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      bool? granted = await androidImplementation.requestPermission();
      if (granted != true) {
        print("알림 권한이 거부되었습니다.");
      } else {
        print("알림 권한이 허용되었습니다.");
      }
    }
  }

  // iOS 알림 권한 요청
  requestIOSPermissions();

  // 알림 스케줄 설정
  scheduleWeeklyNotifications();

  runApp(MyApp());
}

Future<void> initializeNotifications() async {
  // iOS 초기화 설정
  var initializationSettingsIOS = IOSInitializationSettings(
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        print("iOS에서 받은 로컬 알림: $title - $body");
      }
  );

  // Android 초기화 설정
  var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');

  // 초기화 설정 통합
  var initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Android에서 알림 권한 요청 (Android 13 이상)
  if (Platform.isAndroid && await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestPermission() != true) {
    // 권한이 없는 경우 처리
    print("Android 알림 권한이 거부되었습니다.");
  }
}

void requestIOSPermissions() {
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
}

void scheduleWeeklyNotifications() async {
  // 수요일, 금요일, 토요일 9시 이후 알림 스케줄링
  await _scheduleNotification(3, 13, 0, "오늘 번호를 뽑지 않는다면, 내일의 당첨은 없다!", "지금 바로 모히또에서 로또 번호를 생성해보세요~ 🍀", 1);
  await _scheduleNotification(5, 17, 0, "어? 당첨, 냄새가 나죠?", "내일은 로또 당첨 발표일! 모히또에서 로또 1등 당첨되고 경제적 자유을 이루어보세요! 🔥", 2);
  await _scheduleNotification(6, 21, 0, "로또 당첨 결과 등장!", "내용: 떨어지면 한 1년 동안 모희또 안 하면 되거든요. 당첨 확인하러 가기~ 🚀", 3);
}

Future<void> _scheduleNotification(int weekday, int hour, int minute, String title, String body, int id) async {
  var androidDetails = const AndroidNotificationDetails('high_importance_channel', 'High Importance Notifications');
  var iosDetails = const IOSNotificationDetails();
  var notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

  var now = tz.TZDateTime.now(tz.local);
  var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
      .add(Duration(days: (weekday - now.weekday) % 7));

  print('Scheduled notification for $scheduledDate');  // 알림 스케줄 확인 로그

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    title,
    body,
    scheduledDate,
    notificationDetails,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 상태 표시줄 배경색 설정
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF242A3B), // 상태 표시줄의 배경색 설정
      statusBarBrightness: Brightness.dark, // iOS용 상태 표시줄 아이콘 밝기
      statusBarIconBrightness: Brightness.light, // 상태 표시줄 아이콘의 밝기 설정
    ));

    return MaterialApp(
      title: '모희또',
      home: WebAppScreen(),
    );
  }
}

class WebAppScreen extends StatefulWidget {
  @override
  _WebAppScreenState createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  final Completer<WebViewController> _controllerCompleter = Completer<WebViewController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 상태 표시줄과 동일한 색상의 Container를 추가하여 상태 바 영역을 덮음
          Container(
            height: MediaQuery.of(context).padding.top, // 상태 표시줄 높이만큼 설정
            color: const Color(0xFF242A3B), // 상태 표시줄과 같은 색상 설정
          ),
          Expanded(
            child: WebView(
              initialUrl: 'https://mohito.co.kr',
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController webViewController) {
                _controllerCompleter.complete(webViewController);
              },
              onPageFinished: (String url) async {
                final controller = await _controllerCompleter.future;
                await controller.runJavascriptReturningResult(
                  "navigator.__defineGetter__('userAgent', function() { return 'Mozilla/5.0 (Linux; Android 10; Mobile; rv:81.0) Gecko/81.0 Firefox/81.0'; });",
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
