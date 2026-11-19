import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/app_links/otpauth_totp.dart';

void main() {
  OtpAuthTotpLink parse(String label, [String query = '']) => OtpAuthTotpLink(Uri.parse('otpauth://totp/$label?secret=JBSWY3DPEHPK3PXP$query'));

  test('reads issuer prefixes with either separator and accepts labels without a prefix', () {
    for (final OtpAuthTotpLink link in [
      parse('Atelier%20QA:Compte%20Beta', '&issuer=Atelier%20QA'),
      parse('Atelier%20QA%3A%20Compte%20Beta'),
      parse('Compte%20Beta', '&issuer=Atelier%20QA'),
    ]) {
      expect(link.label, 'Compte Beta');
      expect(link.issuer, 'Atelier QA');
    }

    final OtpAuthTotpLink distinct = parse('Archive:Compte', '&issuer=Atelier');
    expect(distinct.label, 'Archive:Compte');
    expect(distinct.issuer, 'Atelier');
  });

  test('exports the issuer prefix and preserves encoded account characters on reimport', () {
    final link = OtpAuthTotpLink.build(secret: 'JBSWY3DPEHPK3PXP', label: 'QA/100%:Test', issuer: 'Atelier');
    expect(link.pathSegments.single, 'Atelier:QA/100%:Test');
    final imported = OtpAuthTotpLink(Uri.parse(link.toString()));
    expect(imported.label, 'QA/100%:Test');
    expect(imported.issuer, 'Atelier');
    expect(imported.encodedSecret, link.encodedSecret);
  });
}
