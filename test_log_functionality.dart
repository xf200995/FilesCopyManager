// 日志功能测试
void main() {
  print('测试拷贝日志功能...');
  
  // 测试日志条目创建
  final entry = CopyLogEntry(
    timestamp: DateTime.now(),
    sourcePath: 'C:\\test\\file1.txt',
    destinationPath: 'D:\\backup\\file1.txt',
    fileSize: 1024 * 1024, // 1MB
    success: true,
  );
  
  print('日志条目创建成功: ${entry.sourcePath} -> ${entry.destinationPath}');
  print('文件大小: ${(entry.fileSize / 1024).toStringAsFixed(2)} KB');
  print('状态: ${entry.success ? '成功' : '失败'}');
  
  // 测试JSON序列化
  final json = entry.toJson();
  print('JSON序列化: $json');
  
  // 测试JSON反序列化
  final entry2 = CopyLogEntry.fromJson(json);
  print('JSON反序列化成功: ${entry2.sourcePath}');
  
  print('日志功能测试完成！');
}