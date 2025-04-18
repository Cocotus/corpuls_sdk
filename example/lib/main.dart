import 'dart:async';

import 'package:corpuls_sdk/corpuls_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _feedback = 'No feedback yet';
  final _Plugin = CorpulsSdk();
  static const platform = MethodChannel('corpuls_sdk');
  List<String> _logsAndData = [];
  bool _isDeviceLocked = false;
  bool _noData = false;

  final List<String> _nodesToDisplay = [
    'geburtsdatum',
    'vorname',
    'nachname',
    'geschlecht',
    'titel',
    'postleitzahl',
    'ort',
    'wohnsitzlaendercode',
    'strasse',
    'hausnummer',
    'beginn',
    'kostentraegerkennung',
    'kostentraegerlaendercode',
    'name',
    'versichertenart',
    'versicherten_id'
  ];

  @override
  void initState() {
    super.initState();
    initPlatformState();
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'log':
        setState(() {
          _logsAndData.add(call.arguments);
        });
        break;
      case 'data':
        setState(() {
          final dataStrings = List<String>.from(call.arguments);
          final filteredDataNodes = _parseAndFilterXmlData(dataStrings);
          _logsAndData.addAll(filteredDataNodes
              .map((node) => '${node.keys.first}: ${node.values.first}'));
        });
        break;
      case 'deviceIsLocked':
        setState(() {
          _isDeviceLocked = true;
        });
        break;
      case 'noData':
        setState(() {
          _noData = true;
        });
        break;
    }
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _Plugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _updateFeedback(
      String methodName, Future<String> Function() method) async {
    try {
      final result = await method();
      setState(() {
        _feedback = '$methodName: $result';
      });
    } catch (e) {
      setState(() {
        _feedback = '$methodName failed: $e';
      });
    }
  }

  List<Map<String, String>> _parseAndFilterXmlData(List<String> dataStrings) {
    List<Map<String, String>> nodes = [];
/*    for (var data in dataStrings) {
      final document = XmlDocument.parse(data);
      final elements = document.findAllElements('*');
      for (var element in elements) {
        final nodeName = element.name.toString().toLowerCase();
        if (_nodesToDisplay.contains(nodeName)) {
          final nodeContent = element.innerText;
          final formattedContent = _formatNodeContent(nodeName, nodeContent);
          nodes.add({element.name.toString(): formattedContent});
        }
      }
    }*/
    return nodes;
  }

  String _formatNodeContent(String nodeName, String content) {
    if ((nodeName == 'geburtsdatum' || nodeName == 'beginn') &&
        content.length == 8) {
      final year = content.substring(0, 4);
      final month = content.substring(4, 6);
      final day = content.substring(6, 8);
      return '$day.$month.$year';
    }
    return content;
  }

  void _clearLogsAndData() {
    setState(() {
      _logsAndData.clear();
      _isDeviceLocked = false;
      _noData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Card Data Manager'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Platform Version: $_platformVersion\n'),
              Text('Feedback: $_feedback\n'),
              if (_isDeviceLocked)
                Text('Device is locked',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              if (_noData)
                Text('No card inserted',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: () {
                  _clearLogsAndData();
                  _updateFeedback('Connect to Device', () async {
                    const uuid =
                        'YOUR_DEVICE_UUID_HERE'; // Replace with the actual UUID
                    final result = await _Plugin.connectCorpuls(uuid);
                    return result ?? 'No result';
                  });
                },
                child: const Text('Connect to Device'),
              ),
              ElevatedButton(
                onPressed: () {
                  _clearLogsAndData();
                  _updateFeedback('Connect to Device', () async {
                    const uuid =
                        'YOUR_DEVICE_UUID_HERE'; // Replace with the actual UUID
                    final result = await _Plugin.connectCorpuls(uuid);
                    return result ?? 'No result';
                  });
                },
                child: const Text('Connect to Device'),
              ),
              ElevatedButton(
                onPressed: () {
                  _clearLogsAndData();
                  _updateFeedback('Connect to Device', () async {
                    const uuid = ''; // Replace with the actual UUID
                    final result = await _Plugin.connectCorpuls(uuid);
                    return result ?? 'No result';
                  });
                },
                child: const Text('Connect to Device'),
              ),
              ElevatedButton(
                onPressed: () {
                  _clearLogsAndData();
                  _updateFeedback('Connect to Device', () async {
                    const uuid =
                        'YOUR_DEVICE_UUID_HERE'; // Replace with the actual UUID
                    final result = await _Plugin.connectCorpuls(uuid);
                    return result ?? 'No result';
                  });
                },
                child: const Text('Connect to Device'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _logsAndData.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_logsAndData[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
