import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/sharing/tiktok_link.dart';

void main() {
  group('parseTikTokShare', () {
    test('extracts a full tiktok.com video URL from shared text', () {
      const text = 'Check this out https://www.tiktok.com/@user/video/12345 ';
      expect(
        parseTikTokShare(text),
        'https://www.tiktok.com/@user/video/12345',
      );
    });

    test('extracts a vt.tiktok.com short link', () {
      const text = 'https://vt.tiktok.com/ZS6abcDEF/';
      expect(parseTikTokShare(text), 'https://vt.tiktok.com/ZS6abcDEF/');
    });

    test('extracts a vm.tiktok.com short link', () {
      const text = 'https://vm.tiktok.com/ZM6abcDEF/';
      expect(parseTikTokShare(text), 'https://vm.tiktok.com/ZM6abcDEF/');
    });

    test('non-TikTok URL yields null', () {
      expect(
        parseTikTokShare('https://www.instagram.com/reel/abc123/'),
        isNull,
      );
    });

    test('plain text with no URL yields null', () {
      expect(parseTikTokShare('just some text, no link'), isNull);
    });

    test('garbage input never throws', () {
      expect(parseTikTokShare(''), isNull);
      expect(parseTikTokShare('http://'), isNull);
    });
  });
}
