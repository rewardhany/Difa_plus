import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'dummy-api-key',
      appId: '1:123456789:web:123456789',
      messagingSenderId: '123456789',
      projectId: 'difa-plus-dummy',
    );
  }
}
