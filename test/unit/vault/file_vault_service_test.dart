import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tripper/core/files/file_vault_service.dart';

void main() {
  late Directory tempDir;
  late FileVaultService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vault_test');
    service = FileVaultService(() async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> sourceFile(String name, [String content = 'data']) async {
    final f = File(p.join(tempDir.path, name));
    await f.writeAsString(content);
    return f;
  }

  test('import copies into vault dir with uuid name, keeps extension',
      () async {
    final src = await sourceFile('boarding-pass.pdf');
    final vaultPath = await service.import(src.path);

    expect(vaultPath, isNot(src.path));
    expect(p.extension(vaultPath), '.pdf');
    expect(p.dirname(vaultPath), p.join(tempDir.path, 'vault'));
    expect(await File(vaultPath).readAsString(), 'data');
    // Source is untouched.
    expect(await src.exists(), isTrue);
  });

  test('import rejects oversized files', () async {
    final src = File(p.join(tempDir.path, 'huge.bin'));
    final raf = await src.open(mode: FileMode.write);
    await raf.truncate(FileVaultService.maxFileBytes + 1);
    await raf.close();

    expect(
      () => service.import(src.path),
      throwsA(isA<FileTooLargeException>()),
    );
  });

  test('delete removes the file; deleting twice is safe', () async {
    final src = await sourceFile('a.png');
    final vaultPath = await service.import(src.path);
    await service.delete(vaultPath);
    expect(await File(vaultPath).exists(), isFalse);
    await service.delete(vaultPath);
  });

  test('sweepOrphans deletes unreferenced files and reports missing ones',
      () async {
    final src = await sourceFile('a.pdf');
    final kept = await service.import(src.path);
    final orphan = await service.import(src.path);
    await service.delete(orphan);
    final orphan2 = await service.import(src.path);

    final missing = await service.sweepOrphans({kept, '/nonexistent/x.pdf'});

    expect(await File(kept).exists(), isTrue);
    expect(await File(orphan2).exists(), isFalse);
    expect(missing, ['/nonexistent/x.pdf']);
  });

  test('a custom subfolder keeps files separate from the default vault dir',
      () async {
    final covers = FileVaultService(() async => tempDir, subfolder: 'covers');
    final src = await sourceFile('sunset.jpg');
    final coverPath = await covers.import(src.path);

    expect(p.dirname(coverPath), p.join(tempDir.path, 'covers'));
    expect(await File(coverPath).exists(), isTrue);

    // sweepOrphans only ever sees its own subfolder — a file a different
    // FileVaultService instance owns must not be treated as this one's
    // orphan (the whole reason cover photos get their own subfolder).
    final missing = await service.sweepOrphans({});
    expect(await File(coverPath).exists(), isTrue);
    expect(missing, isEmpty);
  });
}
