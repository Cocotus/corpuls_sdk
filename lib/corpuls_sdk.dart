
import 'corpuls_sdk_platform_interface.dart';

class CorpulsSdk {
  Future<String?> getPlatformVersion() {
    return CorpulsSdkPlatform.instance.getPlatformVersion();
  }
}
