import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/image_cache.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/widgets/sized_scalable_image.dart';
import 'package:open_authenticator/widgets/smart_image.dart';
import 'package:open_authenticator/widgets/totp/time_based.dart';

/// Displays a TOTP image.
class TotpImage extends ConsumerWidget {
  /// The default size.
  static const double kDefaultSize = 100;

  /// The TOTP UUID.
  final String? uuid;

  /// The TOTP image URL.
  final String? imageUrl;

  /// The TOTP label.
  final String? label;

  /// The TOTP issuer.
  final String? issuer;

  /// The size.
  final double size;

  /// Creates a new TOTP image widget instance.
  const TotpImage({
    super.key,
    this.uuid,
    this.imageUrl,
    required this.label,
    this.issuer,
    this.size = kDefaultSize,
  });

  /// Creates a new TOTP image widget instance from a TOTP instance.
  TotpImage.fromTotp({
    Key? key,
    required Totp totp,
    double size = kDefaultSize,
  }) : this(
         key: key,
         uuid: totp.uuid,
         imageUrl: totp.isDecrypted ? (totp as DecryptedTotp).imageUrl : null,
         label: totp.isDecrypted ? (totp as DecryptedTotp).label : null,
         issuer: totp.isDecrypted ? (totp as DecryptedTotp).issuer : null,
         size: size,
       );

  /// Returns a seeded random color that corresponds to the [issuer] and the [label].
  Color get _filterColor {
    if ((label == null || label!.isEmpty) && (issuer == null || issuer!.isEmpty)) {
      return Colors.transparent;
    }
    Random random = Random(label.hashCode + (issuer ?? '').hashCode);
    return Colors.primaries[random.nextInt(Colors.primaries.length)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uuid == null) {
      return _makeCircle(_createDefaultImage());
    }

    AsyncValue<ResolvedTotpImage?> resolved = ref.watch(
      totpResolvedImageProvider((
        uuid: uuid!,
        imageUrl: imageUrl,
      )),
    );

    return _makeCircle(
      switch (resolved) {
        AsyncData(:final value) when value != null => SmartImage(
          imageKey: ValueKey('$uuid/$imageUrl'),
          source: value.source,
          height: size,
          width: size,
          fit: BoxFit.contain,
          imageType: value.imageType,
          errorBuilder: (_) => _createPlaceholderImage(),
        ),
        _ => _createDefaultImage(),
      },
    );
  }

  /// Makes a circle widget.
  Widget _makeCircle(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(size),
    child: SizedBox.square(
      dimension: size,
      child: child,
    ),
  );

  /// Creates the default image.
  Widget _createDefaultImage() => imageUrl == null
      ? _createPlaceholderImage()
      : ResolvedSmartImage(
          source: imageUrl!,
          height: size,
          width: size,
          fit: BoxFit.contain,
          errorBuilder: (_) => _createPlaceholderImage(),
        );

  /// Creates the local placeholder image, with the app logo inside.
  Widget _createPlaceholderImage() => ColorFiltered(
    colorFilter: ColorFilter.mode(
      _filterColor,
      BlendMode.color,
    ),
    child: SizedScalableImage(
      height: size,
      width: size,
      asset: 'assets/images/logo.si',
    ),
  );
}

/// Displays the TOTP image with a countdown.
class TotpCountdownImage extends StatelessWidget {
  /// The TOTP.
  final Totp totp;

  /// The circle size.
  final double size;

  /// The progress color.
  final MaterialColor progressColor;

  /// Creates a new TOTP countdown image widget instance.
  const TotpCountdownImage({
    super.key,
    required this.totp,
    this.size = 30,
    this.progressColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      children: [
        Positioned.fill(
          child: TotpImage.fromTotp(
            totp: totp,
          ),
        ),
        Positioned.fill(
          child: _TotpCountdownImageCircularProgress(
            totp: totp,
            size: size,
            progressColor: progressColor,
          ),
        ),
      ],
    ),
  );
}

/// Displays the TOTP image with a countdown.
class _TotpCountdownImageCircularProgress extends TimeBasedTotpWidget {
  /// The circle size.
  final double size;

  /// The progress color.
  final MaterialColor progressColor;

  /// Creates a new TOTP countdown image widget instance.
  const _TotpCountdownImageCircularProgress({
    required super.totp,
    this.size = 30,
    this.progressColor = Colors.green,
  });

  @override
  State<TimeBasedTotpWidget> createState() => _TotpCountdownImageCircularProgressState();
}

/// The TOTP countdown image widget state.
class _TotpCountdownImageCircularProgressState extends TimeBasedTotpWidgetState<_TotpCountdownImageCircularProgress> with WidgetsBindingObserver, TickerProviderStateMixin {
  /// The progress indicator color.
  late Color color = widget.progressColor.shade700;

  /// The progress indicator background color.
  late Color backgroundColor = widget.progressColor.shade100;

  /// The animation controller.
  late AnimationController animationController;

  @override
  void initState() {
    super.initState();
    if (((DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ validity.inSeconds).isEven) {
      changeColors();
    }
    scheduleAnimation();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) => CircularProgressIndicator(
    value: animationController.value / validity.inSeconds,
    color: color,
    backgroundColor: backgroundColor,
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == .resumed) {
      updateState(changeColors: false);
    }
  }

  @override
  void onTotpChanged(covariant _TotpCountdownImageCircularProgress oldWidget) {
    if (oldWidget.totp.validity == widget.totp.validity) {
      updateState(changeColors: false);
    } else {
      cancelAnimation();
      scheduleAnimation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cancelAnimation();
    super.dispose();
  }

  @override
  void updateState({double? start, bool changeColors = true}) {
    if (mounted) {
      animationController.duration = validity;
      animationController.forward(from: start ?? progress);
      setState(() {
        if (changeColors) {
          this.changeColors();
        }
      });
    }
  }

  /// Schedule the animation.
  void scheduleAnimation() {
    animationController =
        AnimationController(
            vsync: this,
            duration: validity,
            upperBound: validity.inSeconds.toDouble(),
          )
          ..addListener(() {
            setState(() {});
          })
          ..forward(from: progress);
  }

  /// Cancels the animation.
  void cancelAnimation() {
    animationController.dispose();
  }

  /// Changes the colors.
  void changeColors() {
    Color? temporary = color;
    color = backgroundColor;
    backgroundColor = temporary;
  }

  /// Returns the current progress.
  double get progress => (validity - calculateExpirationDuration()).inMilliseconds / 1000;
}
