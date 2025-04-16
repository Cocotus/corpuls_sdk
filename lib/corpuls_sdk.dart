import 'corpuls_sdk_platform_interface.dart';

class CorpulsSdk {
  Future<String?> getPlatformVersion() {
    return CorpulsSdkPlatform.instance.getPlatformVersion();
  }

  /// New method to connect to a Corpuls device by UUID
  Future<String?> connectCorpuls(String uuid) {
    return CorpulsSdkPlatform.instance.connectCorpuls(uuid);
  }
}
