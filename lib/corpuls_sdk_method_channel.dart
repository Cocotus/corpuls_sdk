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

  /// New method to connect to a Corpuls device by UUID
  @override
  Future<String?> connectCorpuls(String uuid) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectCorpuls',
      {'uuid': uuid}, // Pass the UUID as a parameter
    );
    return result;
  }
}
