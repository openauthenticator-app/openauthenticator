part of '../page.dart';

/// Allows to search through the TOTP list.
extension _Search on List<Totp> {
  /// Searches through the TOTP list.
  List<Totp> search(String query) {
    String lowercaseQuery = query.toLowerCase();
    List<Totp> searchResults = [];
    for (Totp totp in this) {
      if (!totp.isDecrypted) {
        if (totp.uuid.contains(lowercaseQuery)) {
          searchResults.add(totp);
        }
        continue;
      }
      DecryptedTotp decryptedTotp = totp as DecryptedTotp;
      if ((decryptedTotp.label != null && decryptedTotp.label!.contains(lowercaseQuery)) || (decryptedTotp.issuer != null && decryptedTotp.issuer!.contains(lowercaseQuery))) {
        searchResults.add(decryptedTotp);
      }
    }
    return searchResults;
  }
}
