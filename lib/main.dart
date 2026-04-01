import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

// 拷贝配置类
class CopyConfig {
  String name;
  String? sourceDirectory;
  String? destinationDirectory;
  List<String> excludedPaths;
  bool shouldDeleteDestDir;

  CopyConfig({
    required this.name,
    this.sourceDirectory,
    this.destinationDirectory,
    List<String>? excludedPaths,
    this.shouldDeleteDestDir = false,
  }) : excludedPaths = excludedPaths ?? [];

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sourceDirectory': sourceDirectory,
      'destinationDirectory': destinationDirectory,
      'excludedPaths': excludedPaths,
      'shouldDeleteDestDir': shouldDeleteDestDir,
    };
  }

  // 从JSON创建
  factory CopyConfig.fromJson(Map<String, dynamic> json) {
    return CopyConfig(
      name: json['name'],
      sourceDirectory: json['sourceDirectory'],
      destinationDirectory: json['destinationDirectory'],
      excludedPaths: List<String>.from(json['excludedPaths'] ?? []),
      shouldDeleteDestDir: json['shouldDeleteDestDir'] ?? false,
    );
  }
}

void main() {
  runApp(const FileCopyManagerApp());
}

class FileCopyManagerApp extends StatelessWidget {
  const FileCopyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文件拷贝管理器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FileCopyManagerScreen(),
    );
  }
}

class FileCopyManagerScreen extends StatefulWidget {
  const FileCopyManagerScreen({super.key});

  @override
  State<FileCopyManagerScreen> createState() => _FileCopyManagerScreenState();
}

class _FileCopyManagerScreenState extends State<FileCopyManagerScreen> {
  List<CopyConfig> _copyConfigs = [];
  int _currentConfigIndex = 0;
  bool _isCopying = false;
  String _copyStatus = '';
  
  // 文本编辑控制器
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _configNameController = TextEditingController();
  
  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    _configNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // 输出SharedPreferences存储路径
    print('SharedPreferences存储路径: ${prefs.getKeys()}');
    final configsJson = prefs.getString('copyConfigs');
    final currentIndex = prefs.getInt('currentConfigIndex') ?? 0;
    
    setState(() {
      if (configsJson != null) {
        final List<dynamic> jsonList = jsonDecode(configsJson);
        _copyConfigs = jsonList.map((json) => CopyConfig.fromJson(json)).toList();
      } else {
        // 默认创建一个配置
        _copyConfigs = [CopyConfig(name: '配置1')];
      }
      
      _currentConfigIndex = currentIndex;
      _updateControllers();
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    print('SharedPreferences存储路径: ${prefs.getKeys()}');
    final configsJson = jsonEncode(_copyConfigs.map((config) => config.toJson()).toList());
    await prefs.setString('copyConfigs', configsJson);
    await prefs.setInt('currentConfigIndex', _currentConfigIndex);
  }

  void _updateControllers() {
    if (_copyConfigs.isEmpty) return;
    
    final currentConfig = _copyConfigs[_currentConfigIndex];
    _sourceController.text = currentConfig.sourceDirectory ?? '';
    _destController.text = currentConfig.destinationDirectory ?? '';
  }

  void _addNewConfig() {
    setState(() {
      final newName = '配置${_copyConfigs.length + 1}';
      _copyConfigs.add(CopyConfig(name: newName));
      _currentConfigIndex = _copyConfigs.length - 1;
      _updateControllers();
      _saveSettings();
    });
  }

  void _deleteConfig(int index) {
    if (_copyConfigs.length <= 1) {
      _showErrorDialog('至少需要保留一个配置');
      return;
    }
    
    setState(() {
      _copyConfigs.removeAt(index);
      if (_currentConfigIndex >= _copyConfigs.length) {
        _currentConfigIndex = _copyConfigs.length - 1;
      }
      _updateControllers();
      _saveSettings();
    });
  }

  void _renameConfig(String newName) {
    if (newName.trim().isEmpty) {
      _showErrorDialog('配置名称不能为空');
      return;
    }
    
    setState(() {
      _copyConfigs[_currentConfigIndex].name = newName.trim();
      _saveSettings();
    });
  }

  void _showRenameDialog() {
    _configNameController.text = _copyConfigs[_currentConfigIndex].name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名配置'),
        content: TextField(
          controller: _configNameController,
          decoration: const InputDecoration(hintText: '输入配置名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _renameConfig(_configNameController.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectSourceDirectory() async {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    final result = await getDirectoryPath(initialDirectory: currentConfig.sourceDirectory);
    if (result != null) {
      setState(() {
        currentConfig.sourceDirectory = result;
        _sourceController.text = result;
      });
      _saveSettings();
    }
  }

  Future<void> _selectDestinationDirectory() async {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    final result = await getDirectoryPath(initialDirectory: currentConfig.destinationDirectory);
    if (result != null) {
      setState(() {
        currentConfig.destinationDirectory = result;
        _destController.text = result;
      });
      _saveSettings();
    }
  }

  Future<void> _addExcludedPath() async {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    if (currentConfig.sourceDirectory == null) {
      _showErrorDialog('请先选择源目录');
      return;
    }

    final results = await getDirectoryPaths(initialDirectory: currentConfig.sourceDirectory);
    if (results.isNotEmpty) {
      final List<String> validPaths = [];
      for (final path in results) {
        // 确保路径不为空且在源目录下
        if (path != null && path.startsWith(currentConfig.sourceDirectory!)) {
          validPaths.add(path);
        }
      }
      
      if (validPaths.isNotEmpty) {
        setState(() {
          currentConfig.excludedPaths.addAll(validPaths);
        });
        _saveSettings();
        
        // 如果有无效路径，显示提示
        if (validPaths.length < results.length) {
          _showErrorDialog('部分路径不在源目录下，已忽略');
        }
      } else {
        _showErrorDialog('请选择源目录下的路径');
      }
    }
  }

  Future<void> _addExcludedFile() async {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    if (currentConfig.sourceDirectory == null) {
      _showErrorDialog('请先选择源目录');
      return;
    }

    final results = await openFiles(initialDirectory: currentConfig.sourceDirectory);
    if (results.isNotEmpty) {
      final List<String> validPaths = [];
      for (final file in results) {
        final filePath = file.path;
        // 确保文件路径不为空且在源目录下
        if (filePath.startsWith(currentConfig.sourceDirectory!)) {
          validPaths.add(filePath);
        }
      }
      
      if (validPaths.isNotEmpty) {
        setState(() {
          currentConfig.excludedPaths.addAll(validPaths);
        });
        _saveSettings();
        
        // 如果有无效路径，显示提示
        if (validPaths.length < results.length) {
          _showErrorDialog('部分文件不在源目录下，已忽略');
        }
      } else {
        _showErrorDialog('请选择源目录下的文件');
      }
    }
  }

  void _removeExcludedPath(int index) {
    setState(() {
      _copyConfigs[_currentConfigIndex].excludedPaths.removeAt(index);
    });
    _saveSettings();
  }

  bool _shouldExclude(String filePath, List<String> excludedPaths) {
    return excludedPaths.any((excluded) {
      return filePath.startsWith(excluded);
    });
  }

  Future<void> _copyFiles() async {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    if (currentConfig.sourceDirectory == null || currentConfig.destinationDirectory == null) {
      _showErrorDialog('请先选择源目录和目标目录');
      return;
    }

    setState(() {
      _isCopying = true;
      _copyStatus = '开始拷贝...';
    });

    try {
      final sourceDir = Directory(currentConfig.sourceDirectory!);
      final destDir = Directory(currentConfig.destinationDirectory!);

      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      } else if (currentConfig.shouldDeleteDestDir) {
        // 删除目标目录下的所有内容
        setState(() {
          _copyStatus = '正在清理目标目录...';
        });
        
        final List<FileSystemEntity> entities = destDir.listSync(recursive: false);
        for (var entity in entities) {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else if (entity is File) {
            await entity.delete();
          }
        }
      }

      await _copyDirectory(sourceDir, currentConfig);

      setState(() {
        _copyStatus = '拷贝完成！';
      });
    } catch (e) {
      setState(() {
        _copyStatus = '拷贝失败: $e';
      });
    } finally {
      setState(() {
        _isCopying = false;
      });
    }
  }

  Future<void> _copyDirectory(Directory source, CopyConfig config) async {
    final List<FileSystemEntity> entities = source.listSync(recursive: false);

    for (var entity in entities) {
      final relativePath = path.relative(entity.path, from: config.sourceDirectory!);
      final destPath = path.join(config.destinationDirectory!, relativePath);

      if (_shouldExclude(entity.path, config.excludedPaths)) {
        setState(() {
          _copyStatus = '跳过: $relativePath';
        });
        continue;
      }

      setState(() {
        _copyStatus = '正在拷贝: $relativePath';
      });

      if (entity is Directory) {
        final destDir = Directory(destPath);
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        await _copyDirectory(entity, config);
      } else if (entity is File) {
        // 确保目标文件所在的目录存在
        final destDir = Directory(path.dirname(destPath));
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        await entity.copy(destPath);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 确保配置列表不为空
    if (_copyConfigs.isEmpty) {
      _copyConfigs = [CopyConfig(name: '默认配置')];
      _currentConfigIndex = 0;
    }
    
    // 确保当前索引有效
    if (_currentConfigIndex >= _copyConfigs.length) {
      _currentConfigIndex = _copyConfigs.length - 1;
    }
    
    final currentConfig = _copyConfigs[_currentConfigIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件拷贝管理器'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 配置管理
              const Text(
                '拷贝配置',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _currentConfigIndex,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: _copyConfigs.asMap().entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _currentConfigIndex = value;
                            _updateControllers();
                            _saveSettings();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showRenameDialog,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('重命名'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addNewConfig,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _deleteConfig(_currentConfigIndex),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('删除'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 源目录选择
              const Text(
                '源目录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sourceController,
                      onChanged: (value) {
                        setState(() {
                          currentConfig.sourceDirectory = value.trim();
                        });
                        _saveSettings();
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '请输入或选择源目录',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      readOnly: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectSourceDirectory,
                    child: const Text('选择目录'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 目标目录选择
              const Text(
                '目标目录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _destController,
                      onChanged: (value) {
                        setState(() {
                          currentConfig.destinationDirectory = value.trim();
                        });
                        _saveSettings();
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '请输入或选择目标目录',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      readOnly: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectDestinationDirectory,
                    child: const Text('选择目录'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 屏蔽路径设置
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '屏蔽路径',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addExcludedPath,
                        icon: const Icon(Icons.folder, size: 16),
                        label: const Text('添加目录'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addExcludedFile,
                        icon: const Icon(Icons.file_copy, size: 16),
                        label: const Text('添加文件'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (currentConfig.excludedPaths.isEmpty)
                const Text(
                  '没有设置屏蔽路径',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentConfig.excludedPaths.length,
                    itemBuilder: (context, index) {
                      final excludedPath = currentConfig.excludedPaths[index];
                      final relativePath = currentConfig.sourceDirectory != null
                          ? path.relative(excludedPath, from: currentConfig.sourceDirectory!)
                          : excludedPath;
                      return ListTile(
                        title: Text(relativePath),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeExcludedPath(index),
                          color: Colors.red,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),

              // 删除目标目录选项
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: currentConfig.shouldDeleteDestDir,
                    onChanged: (value) {
                      setState(() {
                        currentConfig.shouldDeleteDestDir = value ?? false;
                      });
                      _saveSettings();
                    },
                  ),
                  const Text('拷贝前删除目标目录下的所有文件'),
                ],
              ),
              const SizedBox(height: 16),

              // 拷贝按钮
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isCopying ? null : _copyFiles,
                  icon: const Icon(Icons.copy),
                  label: const Text('开始拷贝'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 拷贝状态
              Center(
                child: Text(
                  _copyStatus,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isCopying ? Colors.blue : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
