import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'dart:io' show Platform;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: '06ce9271e4cd2e4e9141c23eee543b6e'); // Kakao Native App Key 설정

  // Timezone 초기화
  tz.initializeTimeZones();
  // 한국 시간대
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

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
  late InAppWebViewController webViewController;
  final List<String> _routeStack = ['/'];
  DateTime? _lastBackPressed;

  // KakaoTalk 로그인 처리 함수
  Future<void> _loginWithKakao() async {
    try {
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token;

      if (isInstalled) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      print('로그인 성공! 토큰: ${token.accessToken}');

      // 로그인 성공 후 사용자 정보 가져오기
      User user = await fetchUserInfo();

      // 로그인 성공 후 WebView에 로그인 성공 메시지, 토큰과 이메일 전달
      String email = user.kakaoAccount?.email ?? 'null';
      webViewController.evaluateJavascript(source: 'loginSuccess("${token.accessToken}", "$email")');
    } catch (error) {
      print('로그인 실패: $error');
      webViewController.evaluateJavascript(source: 'loginFailure("$error")');
    }
  }

  // 사용자 정보 가져오기
  Future<User> fetchUserInfo() async {
    try {
      User user = await UserApi.instance.me();

      print('사용자 정보: ');
      print('이메일: ${user.kakaoAccount?.email}');

      return user;
    } catch (error) {
      print('사용자 정보 가져오기 실패: $error');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (_routeStack.length > 1) {
            final last = _routeStack.removeLast();
            final previous = _routeStack.last;

            // 중복 라우팅 방지 및 루트로 착각 방지
            if (last == previous) {
              return false;
            }

            print('🔙 Navigating back to $previous (from $last)');
            webViewController.evaluateJavascript(source: 'window.history.back()');
            return false;
          }

          final now = DateTime.now();
          if (_lastBackPressed == null || now.difference(_lastBackPressed!) > Duration(seconds: 2)) {
            _lastBackPressed = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('한 번 더 누르면 종료됩니다')),
            );
            return false;
          }

          return true;
        },
        child: Scaffold(
      // Test Start!!!
      // appBar: AppBar(
      //   title: Text("WebView Test"),
      //   actions: [
      //     // 테스트용 로그인 버튼
      //     IconButton(
      //       icon: Icon(Icons.login),
      //       onPressed: _loginWithKakao, // KakaoTalk 로그인 함수 직접 호출
      //     ),
      //   ],
      // ),
      // Test End!!!
          body: SafeArea(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri("https://mohito.co.kr?source=app")),
              // initialUrlRequest: URLRequest(url: WebUri("http://192.168.0.3:8080?source=app")),
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  javaScriptEnabled: true,
                ),
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;

                controller.addJavaScriptHandler(
                  handlerName: 'routeChanged',
                  callback: (args) {
                    final raw = args.first;
                    final parsed = Uri.tryParse(raw);
                    final path = parsed?.path ?? '/';

                    if (_routeStack.isEmpty || _routeStack.last != path) {
                      if (_routeStack.contains(path)) {
                        final idx = _routeStack.indexOf(path);
                        _routeStack.removeRange(idx + 1, _routeStack.length);
                      } else {
                        _routeStack.add(path);
                      }
                      print('📍 Flutter received route: $path');
                    }
                  },
                );
              },
              onLoadStop: (controller, url) {
                if (_routeStack.isEmpty && url != null) {
                  _routeStack.add(url.path);
                }
              },
            ),
          ),
    )
    );
  }
}
