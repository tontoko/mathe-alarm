import 'dart:async';
import 'dart:ffi';

import 'package:flutter/material.dart';

double toDouble(TimeOfDay time) => time.hour + time.minute / 60.0;

void main() {
  runApp(const MyApp());
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
      home: const MyHomePage(title: 'Timers'),
    );
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

class _MyHomePageState extends State<MyHomePage> {
  TimerList _timerList = {};

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

  Future<Null> _addTime(BuildContext context) async {
    final selectedTime =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (selectedTime != null) _addTimer(selectedTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.separated(
          itemCount: _timerList.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final targetTime = _timerList.keys.toList()[index];
            final targetEnabled = _timerList[targetTime]!;
            return ListTile(
              title: Text(
                targetTime.format(context),
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              trailing: Container(
                  child: Icon(
                targetEnabled ? Icons.alarm : Icons.alarm_off,
                color: targetEnabled
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).disabledColor,
              )),
              onTap: () =>
                  setState(() => _timerList[targetTime] = !targetEnabled),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTime(context),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
