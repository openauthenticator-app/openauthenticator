import 'package:flutter/material.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/widgets/sized_scalable_image.dart';

/// The image of an [AuthenticationProvider].
class AuthenticationProviderImage extends StatelessWidget {
  /// The provider instance.
  final String providerId;

  /// The width.
  final double? width;

  /// The height.
  final double? height;

  /// Creates a new Firebase authentication provider image instance.
  const AuthenticationProviderImage({
    super.key,
    required this.providerId,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) => SizedScalableImage(
    asset: 'assets/images/authentication/$providerId.si',
    width: width,
    height: width,
  );
}
