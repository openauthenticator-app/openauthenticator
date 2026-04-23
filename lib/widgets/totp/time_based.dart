import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_authenticator/model/totp/totp.dart';

/// A TOTP expiration time based widget.
abstract class TimeBasedTotpWidget extends StatefulWidget {
  /// The TOTP instance.
  final Totp totp;

  /// Creates a new time based TOTP widget instance.
  const TimeBasedTotpWidget({
    super.key,
    required this.totp,
  });

  @override
  State<TimeBasedTotpWidget> createState();
}

/// The time based TOTP widget state.
abstract class TimeBasedTotpWidgetState<T extends TimeBasedTotpWidget> extends State<T> {
  /// The update timer.
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _scheduleUpdates();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totp != widget.totp) {
      if (oldWidget.totp.validity != widget.totp.validity) {
        _cancelUpdates();
        _scheduleUpdates();
      } else {
        onTotpChanged(oldWidget);
      }
    }
  }

  @override
  void dispose() {
    _cancelUpdates();
    super.dispose();
  }

  /// The validity, in seconds.
  Duration get validity => widget.totp.validity ?? Totp.kDefaultValidity;

  /// Triggered when the state should be updated.
  void updateState();

  /// Triggered when the TOTP changes.
  @protected
  void onTotpChanged(covariant T oldWidget) => updateState();

  /// Schedule the updates.
  void _scheduleUpdates() {
    _updateTimer = Timer(calculateExpirationDuration(), () {
      updateState();
      _updateTimer = Timer.periodic(validity, (_) => updateState());
    });
  }

  /// Cancels the updates.
  void _cancelUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Calculates the expiration duration.
  Duration calculateExpirationDuration([DateTime? date]) {
    date ??= DateTime.now();
    return _calculateExpirationDate(date).difference(date);
  }

  /// Calculates the expiration date.
  DateTime _calculateExpirationDate(DateTime date) {
    int seconds = validity.inSeconds;
    int currentUnixTime = date.toUtc().millisecondsSinceEpoch ~/ 1000;
    int timeStepRemainder = currentUnixTime % seconds;
    int expirationTime = currentUnixTime + (seconds - timeStepRemainder);
    return DateTime.fromMillisecondsSinceEpoch(expirationTime * 1000);
  }
}
