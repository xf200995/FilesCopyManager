import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:files_copy_manager/main.dart';

void main() {
  group('PathMatcher Tests', () {
    const sourceDirectory = r'C:\source';

    // 测试1：递归文件模式（*.json）
    test('Recursive file pattern (*.json)', () {
      final matcher = PathMatcher('*.json', sourceDirectory);
      
      expect(matcher.matches(path.join(sourceDirectory, 'file.json')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'subdir', 'file.json')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'subdir', 'subsubdir', 'file.json')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'file.txt')), false);
      expect(matcher.matches(path.join(sourceDirectory, 'subdir', 'file.txt')), false);
    });

    // 测试2：直接子目录文件模式（*/.json）
    test('Direct subdirectory file pattern (*/.json)', () {
      final matcher = PathMatcher('*/.json', sourceDirectory);
      
      expect(matcher.matches(path.join(sourceDirectory, 'subdir', 'file.json')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'subdir1', 'file.json')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'subdir', 'subsubdir', 'file.json')), false);
      expect(matcher.matches(path.join(sourceDirectory, 'file.json')), false);
    });

    // 测试3：特定子目录文件模式（*/a/.meta）
    test('Specific subdirectory file pattern (*/a/.meta)', () {
      final matcher = PathMatcher('*/a/.meta', sourceDirectory);
      
      expect(matcher.matches(path.join(sourceDirectory, 'a', 'file.meta')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'a', 'config.meta')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'b', 'file.meta')), false);
      expect(matcher.matches(path.join(sourceDirectory, 'a', 'subdir', 'file.meta')), false);
      expect(matcher.matches(path.join(sourceDirectory, 'a', 'file.txt')), false);
    });

    // 测试4：传统前缀匹配（兼容性测试）
    test('Traditional prefix matching', () {
      final matcher = PathMatcher(r'C:\source\exclude', sourceDirectory);
      
      expect(matcher.matches(r'C:\source\exclude'), true);
      expect(matcher.matches(r'C:\source\exclude\file.txt'), true);
      expect(matcher.matches(r'C:\source\other'), false);
    });

    // 测试5：边界情况 - 空模式
    test('Empty pattern', () {
      final matcher = PathMatcher('', sourceDirectory);
      
      expect(matcher.matches(path.join(sourceDirectory, 'file.txt')), false);
    });

    // 测试6：边界情况 - 不在源目录下的路径
    test('Path outside source directory', () {
      final matcher = PathMatcher('*.json', sourceDirectory);
      
      expect(matcher.matches(r'C:\other\file.json'), false);
    });

    // 测试7：混合模式测试
    test('Mixed pattern test', () {
      final matcher1 = PathMatcher('*.json', sourceDirectory);
      final matcher2 = PathMatcher('*/.json', sourceDirectory);
      final matcher3 = PathMatcher('*/a/.meta', sourceDirectory);
      
      expect(matcher1.matches(path.join(sourceDirectory, 'a', 'file.json')), true);
      expect(matcher2.matches(path.join(sourceDirectory, 'a', 'file.json')), true);
      expect(matcher3.matches(path.join(sourceDirectory, 'a', 'file.meta')), true);
      
      expect(matcher3.matches(path.join(sourceDirectory, 'a', 'file.json')), false);
    });

    // 测试8：不同扩展名的测试
    test('Different extensions', () {
      final matcher = PathMatcher('*.txt', sourceDirectory);
      
      expect(matcher.matches(path.join(sourceDirectory, 'doc.txt')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'subdir', 'doc.txt')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'doc.md')), false);
    });

    // 测试9：多级目录特定子目录模式
    test('Multi-level specific subdirectory pattern', () {
      final matcher = PathMatcher('*/data/.xml', sourceDirectory);
      
      expect(matcher.matches(path.join(sourceDirectory, 'data', 'config.xml')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'data', 'settings.xml')), true);
      expect(matcher.matches(path.join(sourceDirectory, 'data', 'sub', 'config.xml')), false);
      expect(matcher.matches(path.join(sourceDirectory, 'other', 'config.xml')), false);
    });

    // 测试10：路径分隔符兼容性测试
    test('Path separator compatibility', () {
      final matcher = PathMatcher('*\\.json', sourceDirectory);
      
      expect(matcher.matches(path.join(sourceDirectory, 'subdir', 'file.json')), true);
    });
  });
}
