import 'package:supabase_flutter/supabase_flutter.dart';

class AccountActionException implements Exception {
  const AccountActionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AccountService {
  AccountService(this.client);
  final SupabaseClient client;

  Future<void> deleteCurrentAccount({
    Future<void> Function()? clearDeviceRegistration,
  }) async {
    final session = client.auth.currentSession;
    if (session == null)
      throw const AccountActionException('Please sign in again.');
    FunctionResponse response;
    try {
      response = await client.functions
          .invoke(
            'delete-account',
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
            body: {'confirmation': 'DELETE'},
          )
          .timeout(const Duration(seconds: 35));
    } on FunctionException catch (error) {
      if (error.status == 409) {
        throw const AccountActionException(
          'Please request administrator account deletion through Tokilo support.',
        );
      }
      throw const AccountActionException(
        'Account deletion could not complete. Please retry or contact Tokilo support.',
      );
    } catch (_) {
      throw const AccountActionException(
        'Account deletion could not complete. Please retry or contact Tokilo support.',
      );
    }
    final data = response.data;
    if (response.status != 200 ||
        data is! Map ||
        data['success'] != true ||
        data['deleted_user_id'] != session.user.id) {
      throw const AccountActionException(
        'Account deletion was not confirmed. Please retry or contact Tokilo support.',
      );
    }
    // A later sign-in must not be signed out by an earlier asynchronous deletion.
    if (client.auth.currentUser?.id == session.user.id) {
      try {
        await clearDeviceRegistration?.call();
      } finally {
        if (client.auth.currentUser?.id == session.user.id) {
          await client.auth.signOut(scope: SignOutScope.local);
        }
      }
    }
  }
}
