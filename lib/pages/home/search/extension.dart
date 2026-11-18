part of '../page.dart';

/// Allows to search through the TOTP list.
extension _Search on List<Totp> {
  /// Searches through the TOTP list.
  List<Totp> search(String query) {
    final String lowercaseQuery = query.toLowerCase();
    final List<Totp> searchResults = [];
    for (final Totp totp in this) {
      if (!totp.isDecrypted) {
        if (totp.uuid.contains(lowercaseQuery)) {
          searchResults.add(totp);
        }
        continue;
      }
      final DecryptedTotp decryptedTotp = totp as DecryptedTotp;
      if ((decryptedTotp.label != null && decryptedTotp.label!.contains(lowercaseQuery)) || (decryptedTotp.issuer != null && decryptedTotp.issuer!.contains(lowercaseQuery))) {
        searchResults.add(decryptedTotp);
      }
    }
    return searchResults;
  }
}
