import 'dart:async';

import 'package:corpuls_sdk/corpuls_sdk.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Corpuls SDK Example'),
        ),
        body: CorpulsDeviceList(),
      ),
    );
  }
}

class CorpulsDeviceList extends StatefulWidget {
  @override
  _CorpulsDeviceListState createState() => _CorpulsDeviceListState();
}

class _CorpulsDeviceListState extends State<CorpulsDeviceList> {
  String? devices = '';
  bool isLoading = false;

  Future<void> scanForDevices() async {
    setState(() {
      isLoading = true;
      devices = "";
    });

    try {
      final sdk = CorpulsSdk();
      final result = await sdk.scanForDevices();
      setState(() {
        devices = result ?? "";
      });
    } catch (e) {
      print('Error scanning for devices: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            CircularProgressIndicator()
          else if (devices != null)
            Text('No devices found')
          else
            Expanded(
              child: ListView.builder(
                itemCount: 1,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(devices ?? ""),
                  );
                },
              ),
            ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: scanForDevices,
            child: Text('Scan for Devices'),
          ),
        ],
      ),
    );
  }
}
