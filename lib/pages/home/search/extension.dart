part of '../page.dart';

/// Allows to search through the TOTP list.
extension _Search on List<Totp> {
  /// Searches through the TOTP list.
  List<Totp> search(String query) {
    final String lowercaseQuery = query.toLowerCase();
    bool matches(String? value) => value?.toLowerCase().contains(lowercaseQuery) ?? false;
    return where(
      (totp) => switch (totp) {
        DecryptedTotp() => matches(totp.label) || matches(totp.issuer),
        _ => matches(totp.uuid),
      },
    ).toList();
  }
}
