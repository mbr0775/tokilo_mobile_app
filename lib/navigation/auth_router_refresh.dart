import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(Stream<AuthState> authChanges) {
    _subscription = authChanges.listen(
      (change) {
        if (change.event == AuthChangeEvent.passwordRecovery) {
          passwordRecoveryActive = true;
        } else if (change.event == AuthChangeEvent.signedOut ||
            change.event == AuthChangeEvent.signedIn) {
          passwordRecoveryActive = false;
        }
        notifyListeners();
      },
      // Auth screens display callback errors; keep the router on that screen.
      onError: (Object _) {},
    );
  }

  late final StreamSubscription<AuthState> _subscription;
  bool passwordRecoveryActive = false;
  bool returningToLogin = false;
  void beginReturnToLogin() {
    returningToLogin = true;
    notifyListeners();
  }

  void completeReturnToLogin() {
    passwordRecoveryActive = false;
    returningToLogin = false;
    notifyListeners();
  }

  void completeRecovery() {
    passwordRecoveryActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
