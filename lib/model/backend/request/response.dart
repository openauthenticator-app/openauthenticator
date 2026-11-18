import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/synchronization/push/result.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/json.dart';

part 'responses/user.dart';
part 'responses/authentication.dart';
part 'responses/synchronization.dart';
part 'responses/backend.dart';

/// Represents a backend response.
abstract class BackendResponse {
  /// Creates a new backend response instance.
  const BackendResponse();
}
