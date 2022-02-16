import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';

import 'model/timer.dart';

double toDouble(TimeOfDay time) => time.hour + time.minute / 60.0;

extension DateTimeExtension on DateTime {
  DateTime applied(TimeOfDay time) {
    return DateTime(year, month, day, time.hour, time.minute);
  }
}

class AppSettingsModel extends ChangeNotifier {
  bool _hardMode = false;
  late SharedPreferences _pref;

  AppSettingsModel(SharedPreferences pref) {
    _pref = pref;
    _init();
  }

  _init() {
    _hardMode = _pref.getBool("hardMode") ?? false;
  }

  void changeMode(bool value) async {
    _pref.setBool('hardMode', value);
    _hardMode = value;
    notifyListeners();
  }
}

class TimerModel extends ChangeNotifier {
  List<AppTimer> timerList = [];
  DateTime now = DateTime.now();
  bool isAlartShow = false;
  late Database _database;

  TimerModel(Database database) {
    _database = database;
    _init();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      now = DateTime.now();
      print(now.toString());
      notifyListeners();
    });
  }

  _init() async {
    await getTimers();
    notifyListeners();
  }

  getTimers() async {
    final List<Map<String, dynamic>> maps = await _database.query("timers");
    timerList = List.generate(maps.length, (i) {
      return AppTimer(
        id: maps[i]['id']!,
        time: TimeOfDay.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(maps[i]['time']),
        ),
        enabled: maps[i]['enabled'] == 1,
      );
    });
  }

  void addTimer(TimeOfDay time) async {
    _database.insert(
      'timers',
      AppTimer(time: time, enabled: true).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await getTimers();
    notifyListeners();
  }

  void updateTimer(AppTimer data) async {
    await _database.update(
      'timers',
      AppTimer(time: data.time, enabled: data.enabled).toMap(),
      where: 'id = ?',
      whereArgs: [data.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await getTimers();
    notifyListeners();
  }

  void removeTimer(int id) async {
    await _database.delete(
      'timers',
      where: 'id = ?',
      whereArgs: [id],
    );
    await getTimers();
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    join(await getDatabasesPath(), 'database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE timers(id INTEGER PRIMARY KEY AUTOINCREMENT, time INTEGER, enabled INTEGER)',
      );
    },
    version: 1,
  );
  final SharedPreferences pref = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AppSettingsModel(pref),
        ),
        ChangeNotifierProvider(
          create: (context) => TimerModel(database),
        )
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => Consumer<TimerModel>(
              builder: (context, timer, child) =>
                  MyHomePage(title: 'Timers', timer: timer),
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
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title, required this.timer})
      : super(key: key);

  final String title;
  final TimerModel timer;

  void addTimer(TimeOfDay selectedTime) async => timer.addTimer(selectedTime);
  void updateTimer(AppTimer data, int id) async => timer.updateTimer(
        AppTimer(id: id, time: data.time, enabled: data.enabled),
      );
  void removeTimer(int id) async => timer.removeTimer(id);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  late Timer? iosSoundTimer;
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
    widget.timer.isAlartShow = true;

    // avoid setState() or markNeedsBuild() called during build
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      showDialog(
        barrierDismissible: false,
        context: this.context,
        builder: (context) => Consumer<AppSettingsModel>(
          builder: (context, settings, child) {
            final baseRandomNum = settings._hardMode ? 99 : 9;
            int numA = Random().nextInt(baseRandomNum);
            int numB = Random().nextInt(baseRandomNum);

            return AlarmAlert(
              handleStopAlarm: _handleStopAlarm,
              numA: numA,
              numB: numB,
            );
          },
        ),
      );
    });
  }

  void _handleStopAlarm() {
    FlutterRingtonePlayer.stop();
    if (iosSoundTimer != null && iosSoundTimer!.isActive) {
      iosSoundTimer!.cancel();
    }
    Navigator.pop(this.context);
    widget.timer.isAlartShow = false;
  }

  @override
  void initState() {
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
      final nextTimer = tz.TZDateTime.fromMicrosecondsSinceEpoch(
        tz.local,
        widget.timer.timerList
            .where((e) => e.enabled)
            .map((e) => DateTime.now().applied(e.time).microsecondsSinceEpoch)
            .reduce(min),
      );
      await FlutterLocalNotificationsPlugin().initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('app_icon'),
          iOS: IOSInitializationSettings(),
        ),
      );
      FlutterLocalNotificationsPlugin().zonedSchedule(
          _notificationId,
          "alart!!",
          "open to solve question",
          nextTimer,
          const NotificationDetails(
            android: AndroidNotificationDetails(
                'your channel id', 'your channel name',
                importance: Importance.max, priority: Priority.high),
            iOS: IOSNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidAllowWhileIdle: true);
    } else if (state == AppLifecycleState.resumed) {
      print('app resumed');
      FlutterLocalNotificationsPlugin().cancel(_notificationId);
    }
  }

  Future<void> _addTime(BuildContext context) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime != null) widget.addTimer(selectedTime);
  }

  Future<void> _editTime(BuildContext context, AppTimer target) async {
    final selectedTime =
        await showTimePicker(context: context, initialTime: target.time);
    if (selectedTime != null) {
      widget.updateTimer(
          AppTimer(time: selectedTime, enabled: target.enabled), target.id!);
    }
  }

  @override
  void didUpdateWidget(covariant MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.timer.isAlartShow &&
        widget.timer.timerList.any((timer) =>
            timer.enabled == true &&
            timer.time.hour == widget.timer.now.hour &&
            timer.time.minute == widget.timer.now.minute &&
            widget.timer.now.second == 0)) {
      _showAlarm();
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
            icon: const Icon(Icons.settings),
          )
        ],
      ),
      body: ListView.separated(
          itemCount: widget.timer.timerList.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final targetTime = widget.timer.timerList[index].time;
            final targetEnabled = widget.timer.timerList[index].enabled;
            final id = widget.timer.timerList[index].id;
            return Dismissible(
              key: Key(targetTime.toString()),
              onDismissed: (direction) => widget.removeTimer(id!),
              background: Container(color: Colors.red),
              child: ListTile(
                title: Text(
                  targetTime.format(context),
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold),
                ),
                trailing: InkWell(
                  onTap: () => widget.updateTimer(
                      AppTimer(time: targetTime, enabled: !targetEnabled), id!),
                  child: Icon(
                    targetEnabled ? Icons.alarm : Icons.alarm_off,
                    color: targetEnabled
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).disabledColor,
                  ),
                ),
                onTap: () => _editTime(context, widget.timer.timerList[index]),
              ),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTime(context),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
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

class _AlarmAlertState extends State<AlarmAlert>
    with SingleTickerProviderStateMixin {
  void _handleAnswer(String value) {
    if (value != '' && int.tryParse(value) == widget.numA * widget.numB) {
      widget.handleStopAlarm();
    }
  }

  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        duration: const Duration(milliseconds: 10), vsync: this);
    animation = Tween<double>(begin: 0, end: 5).animate(controller);
    controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'solve this question to stop alarm',
        style: TextStyle(),
      ),
      content: Column(children: [
        AnimatedAlarm(animation: animation),
        Text("${widget.numA} X ${widget.numB} = ????",
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
        TextField(
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            onChanged: (value) => _handleAnswer(value))
      ]),
    );
  }
}

class AnimatedAlarm extends AnimatedWidget {
  const AnimatedAlarm({Key? key, required Animation<double> animation})
      : super(key: key, listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    return Container(
      height: IconTheme.of(context).size! + 25,
      padding: EdgeInsets.only(bottom: animation.value),
      child: Icon(
        Icons.alarm,
        size: IconTheme.of(context).size! + 20,
      ),
    );
  }
}
