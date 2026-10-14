import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucp/widgets/user_avatar.dart';

void main() {
  group('UserAvatars deterministic mapping', () {
    test('same user always gets the same avatar', () {
      expect(UserAvatars.assetFor('Sara Khan'),
          UserAvatars.assetFor('Sara Khan'));
      expect(UserAvatars.indexFor('sara khan'),
          UserAvatars.indexFor('Sara Khan'));
    });

    test('case and whitespace do not change the avatar', () {
      expect(UserAvatars.assetFor('  Omar  '),
          UserAvatars.assetFor('omar'));
    });

    test('empty identity falls back to the first avatar', () {
      expect(UserAvatars.assetFor(''), 'assets/avatars/avatar_001.png');
      expect(UserAvatars.assetFor(null), 'assets/avatars/avatar_001.png');
      expect(UserAvatars.assetFor('   '), 'assets/avatars/avatar_001.png');
    });

    test('paths stay inside the generated set', () {
      final re = RegExp(r'^assets/avatars/avatar_0\d\d\.png$');
      for (final name in ['a', 'Ahmed Raza', 'l1f25bscs0577@ucp.edu.pk', 'Z']) {
        final asset = UserAvatars.assetFor(name);
        expect(re.hasMatch(asset), isTrue, reason: asset);
        final n = int.parse(asset.split('_').last.split('.').first);
        expect(n, inInclusiveRange(1, UserAvatars.count));
      }
    });

    test('different users spread across avatars', () {
      final seen = <String>{
        for (var i = 0; i < 200; i++) UserAvatars.assetFor('student-$i')
      };
      // DJB2 mod 72 over sequential keys must cover most of the set.
      expect(seen.length, greaterThan(50));
    });
  });

  group('UserAvatar widget', () {
    testWidgets('renders the deterministic asset circularly',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: UserAvatar(userKey: 'Sara Khan', radius: 15),
        ),
      ));
      await tester.pump();
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<AssetImage>());
      expect((img.image as AssetImage).assetName,
          UserAvatars.assetFor('Sara Khan'));
      expect(find.byType(ClipOval), findsOneWidget);
      expect(tester.getSize(find.byType(ClipOval)), const Size(30, 30));
    });
  });
}
