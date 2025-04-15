import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'corpuls_sdk_platform_interface.dart';

/// An implementation of [CorpulsSdkPlatform] that uses method channels.
class MethodChannelCorpulsSdk extends CorpulsSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('corpuls_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> scanForDevices() async {
    final devices = await methodChannel.invokeMethod<String>('scanForDevices');
    return devices;
  }
}
