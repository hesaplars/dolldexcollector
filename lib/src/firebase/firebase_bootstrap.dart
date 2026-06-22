import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase_options.dart';

bool isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<bool> tryInitialize() async {
    try {
      if (isFirebaseInitialized()) {
        return true;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
        );
      }

      return true;
    } catch (error, stackTrace) {
      debugPrint('Firebase unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
