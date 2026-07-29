import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:tripper/core/sharing/share_intent_service.dart';

SharedMediaFile _media(String path, SharedMediaType type) =>
    SharedMediaFile(path: path, type: type);

void main() {
  test('files and images land in files; text and urls in texts', () {
    final share = mapSharedMedia([
      _media('/tmp/ticket.pdf', SharedMediaType.file),
      _media('/tmp/passport.jpg', SharedMediaType.image),
      _media('https://maps.app.goo.gl/xyz', SharedMediaType.url),
      _media('Check this out', SharedMediaType.text),
    ]);
    expect(share.files.map((f) => f.path).toList(), [
      '/tmp/ticket.pdf',
      '/tmp/passport.jpg',
    ]);
    expect(share.texts, [
      'https://maps.app.goo.gl/xyz',
      'Check this out',
    ]);
    expect(share.isEmpty, isFalse);
  });

  test('empty share maps to empty', () {
    expect(mapSharedMedia(const []).isEmpty, isTrue);
  });
}
