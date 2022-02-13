import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter/material.dart';

double toDouble(TimeOfDay time) => time.hour + time.minute / 60.0;

extension DateTimeExtension on DateTime {
  DateTime applied(TimeOfDay time) {
    return DateTime(year, month, day, time.hour, time.minute);
  }
}

class AppSettingsModel extends ChangeNotifier {
  var _hardMode = false;

  void changeMode(bool value) {
    _hardMode = value;
    notifyListeners();
  }
}

void main() {
  runApp(ChangeNotifierProvider(
    create: (context) => AppSettingsModel(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(
              title: 'Timers',
            ),
        '/settings': (context) => const SettingsPage()
      },
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: Consumer<AppSettingsModel>(
            builder: (context, settings, child) => ListView(
                  children: [
                    SwitchListTile(
                      title: const Text('hard mode'),
                      secondary: const Icon(Icons.warning),
                      onChanged: (bool value) {
                        settings.changeMode(value);
                      },
                      value: settings._hardMode,
                    )
                  ],
                )));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

typedef TimerList = Map<TimeOfDay, bool>;

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  TimerList _timerList = {};
  DateTime _now = DateTime.now();
  bool isAlartShow = false;
  late Timer? iosSoundTimer;
  late DateTime _pausedDate;
  late int _notificationId;

  void _showAlarm() {
    if (Platform.isIOS) {
      iosSoundTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        FlutterRingtonePlayer.play(
          android: AndroidSounds.notification,
          ios: IosSounds.alarm,
        );
      });
    } else {
      FlutterRingtonePlayer.play(
        android: AndroidSounds.notification,
        ios: IosSounds.alarm,
        looping: true, // Android only - API >= 28
        volume: 0.4, // Android only - API >= 28
        asAlarm: true, // Android only - all APIs
      );
    }
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) =>
            Consumer<AppSettingsModel>(builder: (context, settings, child) {
              final baseRandomNum = settings._hardMode ? 99 : 9;
              int numA = Random().nextInt(baseRandomNum);
              int numB = Random().nextInt(baseRandomNum);

              return AlarmAlert(
                handleStopAlarm: _handleStopAlarm,
                numA: numA,
                numB: numB,
              );
            }));
    setState(() {
      isAlartShow = true;
    });
  }

  void _handleStopAlarm() {
    FlutterRingtonePlayer.stop();
    if (iosSoundTimer != null && iosSoundTimer!.isActive) {
      iosSoundTimer!.cancel();
    }
    Navigator.pop(context);
    setState(() => isAlartShow = false);
  }

  @override
  void initState() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _now = _now.add(const Duration(seconds: 1)));
      print(_now.toString());
      if (!isAlartShow &&
          _timerList.keys.any((key) =>
              _timerList[key] == true &&
              key.hour == _now.hour &&
              key.minute == _now.minute &&
              _now.second == 0)) {
        _showAlarm();
      }
    });
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      print('app paused');
      _notificationId = DateTime.now().hashCode;
      setState(() {
        _pausedDate = DateTime.now();
      });
      final nextTimer = tz.TZDateTime.fromMicrosecondsSinceEpoch(
          tz.local,
          _timerList.keys
              .where((e) => _timerList[e]!)
              .map((e) => DateTime.now().applied(e).microsecondsSinceEpoch)
              .reduce(min));
      await FlutterLocalNotificationsPlugin().initialize(
          const InitializationSettings(
              android: AndroidInitializationSettings('app_icon'),
              iOS: IOSInitializationSettings()));
      FlutterLocalNotificationsPlugin().zonedSchedule(
          _notificationId,
          "alart!!",
          "open to solve question",
          nextTimer,
          const NotificationDetails(
              android: AndroidNotificationDetails(
                  'your channel id', 'your channel name',
                  importance: Importance.max, priority: Priority.high),
              iOS: IOSNotificationDetails()),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidAllowWhileIdle: true);
    } else if (state == AppLifecycleState.resumed) {
      print('app resumed');
      FlutterLocalNotificationsPlugin().cancel(_notificationId);
      setState(() => _now = DateTime.now());
    }
  }

  void _addTimer(TimeOfDay time) {
    setState(() {
      var timerListCopy = {..._timerList};
      timerListCopy[time] = true;
      var sortedKeys = timerListCopy.keys.toList();
      sortedKeys.sort((a, b) => toDouble(a).compareTo(toDouble(b)));
      TimerList sortedTimerList = {};
      for (var key in sortedKeys) {
        sortedTimerList[key] = timerListCopy[key]!;
      }
      _timerList = sortedTimerList;
    });
  }

  void _removeTimer(TimeOfDay time) {
    setState(() {
      _timerList.remove(time);
    });
  }

  Future<void> _addTime(BuildContext context) async {
    final selectedTime =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (selectedTime != null) _addTimer(selectedTime);
  }

  Future<void> _editTime(BuildContext context, TimeOfDay targetTime) async {
    final selectedTime =
        await showTimePicker(context: context, initialTime: targetTime);
    if (selectedTime != null) {
      _removeTimer(targetTime);
      _addTimer(selectedTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings))
        ],
      ),
      body: ListView.separated(
          itemCount: _timerList.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final targetTime = _timerList.keys.toList()[index];
            final targetEnabled = _timerList[targetTime]!;
            return Dismissible(
                key: Key(targetTime.toString()),
                onDismissed: (direction) => _removeTimer(targetTime),
                background: Container(color: Colors.red),
                child: ListTile(
                    title: Text(
                      targetTime.format(context),
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    trailing: InkWell(
                        onTap: () => setState(
                            () => _timerList[targetTime] = !targetEnabled),
                        child: Icon(
                          targetEnabled ? Icons.alarm : Icons.alarm_off,
                          color: targetEnabled
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).disabledColor,
                        )),
                    onTap: () => _editTime(context, targetTime)));
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTime(context),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class AlarmAlert extends StatefulWidget {
  final int numA;
  final int numB;
  final VoidCallback handleStopAlarm;
  const AlarmAlert(
      {Key? key,
      required this.numA,
      required this.numB,
      required this.handleStopAlarm})
      : super(key: key);

  @override
  _AlarmAlertState createState() => _AlarmAlertState();
}

class _AlarmAlertState extends State<AlarmAlert> {
  void _handleAnswer(String value) {
    if (value != '' && int.tryParse(value) == widget.numA * widget.numB) {
      widget.handleStopAlarm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text(
          'solve this question to stop alarm',
          style: TextStyle(),
        ),
        content: Column(children: [
          Text("${widget.numA} X ${widget.numB} = ????",
              style:
                  const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (value) => _handleAnswer(value))
        ]));
  }
}
