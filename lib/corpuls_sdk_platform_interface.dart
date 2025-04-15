import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'corpuls_sdk_method_channel.dart';

abstract class CorpulsSdkPlatform extends PlatformInterface {
  /// Constructs a CorpulsSdkPlatform.
  CorpulsSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static CorpulsSdkPlatform _instance = MethodChannelCorpulsSdk();

  /// The default instance of [CorpulsSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelCorpulsSdk].
  static CorpulsSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CorpulsSdkPlatform] when
  /// they register themselves.
  static set instance(CorpulsSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> scanForDevices();
}
