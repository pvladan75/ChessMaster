import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/services/crash_breadcrumb_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crash_test');
    CrashBreadcrumbService.instance.setTestDirectory(() async => tempDir);
  });

  tearDown(() async {
    CrashBreadcrumbService.instance.setTestDirectory(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a record is written', () async {
    await CrashBreadcrumbService.instance
        .recordError(Exception('Test error'), StackTrace.empty);

    final logFile = File(
        '${tempDir.path}${Platform.pathSeparator}crash_logs${Platform.pathSeparator}crash.log');
    expect(await logFile.exists(), isTrue);
    final content = await logFile.readAsString();
    expect(content, contains('Exception: Test error'));
  });

  test('the cap holds when the file is already full', () async {
    final logFile = File(
        '${tempDir.path}${Platform.pathSeparator}crash_logs${Platform.pathSeparator}crash.log');
    await logFile.create(recursive: true);

    // Fill the file just over the 256KB limit
    final chunk = 'A' * 1024; // 1KB
    final sink = logFile.openWrite();
    for (int i = 0; i < 260; i++) {
      sink.writeln(chunk);
    }
    await sink.close();

    expect(await logFile.length(), greaterThan(256 * 1024));

    await CrashBreadcrumbService.instance
        .recordError(Exception('Cap error'), StackTrace.empty);

    // The cap logic in the service cuts the lines in half, so it should be significantly smaller now
    expect(await logFile.length(), lessThan(256 * 1024));
    final content = await logFile.readAsString();
    expect(content, contains('Exception: Cap error'));
  });

  test(
      'a write into an unwritable directory returns quietly instead of throwing',
      () async {
    // In Windows, a truly unwritable directory in a temp folder might be tricky to create via standard dart:io without admin/ACL manipulation.
    // However, we can simulate an unwritable directory by injecting a path that points to a file, causing Directory.create() to fail.
    final unwritableTarget =
        File('${tempDir.path}${Platform.pathSeparator}fake_dir');
    await unwritableTarget.writeAsString('I am a file');

    CrashBreadcrumbService.instance
        .setTestDirectory(() async => Directory(unwritableTarget.path));

    // This should not throw
    await CrashBreadcrumbService.instance
        .recordError(Exception('Unwritable error'), StackTrace.empty);
  });
}
