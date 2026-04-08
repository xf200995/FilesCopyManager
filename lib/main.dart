import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'colors.dart';

// 屏蔽路径子界面
class ExcludedPathsScreen extends StatefulWidget {
  final CopyConfig config;
  final VoidCallback onConfigChanged;

  const ExcludedPathsScreen({
    Key? key,
    required this.config,
    required this.onConfigChanged,
  }) : super(key: key);

  @override
  State<ExcludedPathsScreen> createState() => _ExcludedPathsScreenState();
}

// 拷贝配置管理子界面
class CopyConfigManagerScreen extends StatefulWidget {
  final List<CopyConfig> copyConfigs;
  final int selectedIndex;
  final Function(int) onSelectConfig;
  final Function(int) onEditConfig;

  const CopyConfigManagerScreen({
    Key? key,
    required this.copyConfigs,
    required this.selectedIndex,
    required this.onSelectConfig,
    required this.onEditConfig,
  }) : super(key: key);

  @override
  State<CopyConfigManagerScreen> createState() => _CopyConfigManagerScreenState();
}

class _CopyConfigManagerScreenState extends State<CopyConfigManagerScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拷贝配置管理'),
        backgroundColor: MorandiColors.buttonPrimary.color,
        foregroundColor: MorandiColors.buttonText.color,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.copyConfigs.length,
                itemBuilder: (context, index) {
                  final config = widget.copyConfigs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        widget.onSelectConfig(index);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedIndex == index 
                                ? MorandiColors.buttonPrimary.color 
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  config.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Radio<int>(
                                  value: index,
                                  groupValue: _selectedIndex,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedIndex = value;
                                      });
                                      widget.onSelectConfig(value);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildPathItem('源目录:', config.sourceDirectory),
                            _buildPathItem('目标目录:', config.destinationDirectory),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 底部功能区
            Visibility(
              visible: _selectedIndex >= 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(top: 16.0),
                decoration: BoxDecoration(
                  color: MorandiColors.executeArea.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        widget.onEditConfig(_selectedIndex);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MorandiColors.buttonPrimary.color,
                        foregroundColor: MorandiColors.buttonText.color,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('编辑配置'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathItem(String label, String? path) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path ?? '未设置',
              style: TextStyle(
                color: path != null ? MorandiColors.textPrimary.color : Colors.grey,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExcludedPathsScreenState extends State<ExcludedPathsScreen> {
  Future<void> _addExcludedPath() async {
    final results = await getDirectoryPaths(initialDirectory: widget.config.sourceDirectory);
    if (results.isNotEmpty) {
      final validPaths = results
          .where((path) => path != null && !widget.config.excludedPaths.contains(path))
          .cast<String>()
          .toList();
      if (validPaths.isNotEmpty) {
        setState(() {
          widget.config.excludedPaths.addAll(validPaths);
        });
        widget.onConfigChanged();
      }
    }
  }

  Future<void> _addExcludedFile() async {
    final results = await openFiles(initialDirectory: widget.config.sourceDirectory);
    if (results.isNotEmpty) {
      final validPaths = results
          .map((xFile) => xFile.path)
          .where((path) => !widget.config.excludedPaths.contains(path))
          .toList();
      if (validPaths.isNotEmpty) {
        setState(() {
          widget.config.excludedPaths.addAll(validPaths);
        });
        widget.onConfigChanged();
      }
    }
  }

  void _removeExcludedPath(int index) {
    setState(() {
      widget.config.excludedPaths.removeAt(index);
    });
    widget.onConfigChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('屏蔽路径管理'),
        backgroundColor: MorandiColors.buttonPrimary.color,
        foregroundColor: MorandiColors.buttonText.color,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '配置: ${widget.config.name}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MorandiColors.textPrimary.color,
              ),
            ),
            const SizedBox(height: 20),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.folder,
                  label: '添加目录',
                  onPressed: _addExcludedPath,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.file_copy,
                  label: '添加文件',
                  onPressed: _addExcludedFile,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 屏蔽路径列表
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: MorandiColors.excludeArea.color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MorandiColors.border.color),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '屏蔽路径列表',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MorandiColors.textPrimary.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (widget.config.excludedPaths.isEmpty)
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MorandiColors.border.color),
                            ),
                            child: Text(
                              '没有设置屏蔽路径',
                              style: TextStyle(
                                fontSize: 16,
                                color: MorandiColors.textSecondary.color,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.config.excludedPaths.length,
                          itemBuilder: (context, index) {
                            final excludedPath = widget.config.excludedPaths[index];
                            final relativePath = widget.config.sourceDirectory != null
                                ? path.relative(excludedPath, from: widget.config.sourceDirectory!)
                                : excludedPath;
                            final fileName = path.basename(excludedPath);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  FileSystemEntity.typeSync(excludedPath) == FileSystemEntityType.directory
                                      ? Icons.folder
                                      : Icons.file_copy,
                                  color: MorandiColors.buttonPrimary.color,
                                ),
                                title: Text(
                                  fileName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: MorandiColors.textPrimary.color,
                                  ),
                                ),
                                subtitle: Text(
                                  relativePath,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: MorandiColors.textSecondary.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _removeExcludedPath(index),
                                  color: Colors.red[400],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 16) : null,
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: MorandiColors.buttonSecondary.color,
        foregroundColor: MorandiColors.buttonText.color,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

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

  void _openSourceDirectory() {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    if (currentConfig.sourceDirectory == null || currentConfig.sourceDirectory!.isEmpty) {
      _showErrorDialog('源目录未配置');
      return;
    }
    
    try {
      final directory = Directory(currentConfig.sourceDirectory!);
      if (!directory.existsSync()) {
        _showErrorDialog('源目录不存在：${currentConfig.sourceDirectory}');
        return;
      }
      launchUrl(
        Uri.file(currentConfig.sourceDirectory!),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _showErrorDialog('无法打开源目录：$e');
    }
  }

  void _openDestinationDirectory() {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    if (currentConfig.destinationDirectory == null || currentConfig.destinationDirectory!.isEmpty) {
      _showErrorDialog('目标目录未配置');
      return;
    }
    
    try {
      final directory = Directory(currentConfig.destinationDirectory!);
      if (!directory.existsSync()) {
        _showErrorDialog('目标目录不存在：${currentConfig.destinationDirectory}');
        return;
      }
      launchUrl(
        Uri.file(currentConfig.destinationDirectory!),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _showErrorDialog('无法打开目标目录：$e');
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

  void _openExcludedPathsScreen() {
    final currentConfig = _copyConfigs[_currentConfigIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExcludedPathsScreen(
          config: currentConfig,
          onConfigChanged: () {
            setState(() {
              // 配置已在子界面中更新，这里只需要触发重绘
            });
            _saveSettings();
          },
        ),
      ),
    );
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

  // 导入配置
  Future<void> _importConfig() async {
    try {
      final result = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'JSON配置文件',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );

      if (result != null) {
        final content = await result.readAsString();
        final jsonData = json.decode(content);

        if (jsonData is List) {
          // 导入多个配置
          for (var configData in jsonData) {
            final importedConfig = CopyConfig.fromJson(configData as Map<String, dynamic>);
            // 检查是否存在同名配置
            final existingIndex = _copyConfigs.indexWhere((config) => config.name == importedConfig.name);
            if (existingIndex >= 0) {
              // 覆盖同名配置
              _copyConfigs[existingIndex] = importedConfig;
            } else {
              // 添加新配置
              _copyConfigs.add(importedConfig);
            }
          }
        } else if (jsonData is Map) {
          // 导入单个配置
          final importedConfig = CopyConfig.fromJson(jsonData as Map<String, dynamic>);
          // 检查是否存在同名配置
          final existingIndex = _copyConfigs.indexWhere((config) => config.name == importedConfig.name);
          if (existingIndex >= 0) {
            // 覆盖同名配置
            _copyConfigs[existingIndex] = importedConfig;
          } else {
            // 添加新配置
            _copyConfigs.add(importedConfig);
          }
        }

        setState(() {
          _updateControllers();
          _saveSettings();
        });

        _showSuccessDialog('配置导入成功');
      }
    } catch (e) {
      _showErrorDialog('配置导入失败: $e');
    }
  }

  // 显示导出对话框
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出配置'),
        content: const Text('请选择导出模式'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportCurrentConfig();
            },
            child: const Text('导出当前配置'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportAllConfigs();
            },
            child: const Text('导出所有配置'),
          ),
        ],
      ),
    );
  }

  // 导出当前配置
  Future<void> _exportCurrentConfig() async {
    try {
      final currentConfig = _copyConfigs[_currentConfigIndex];
      final configData = currentConfig.toJson();
      final jsonString = json.encode(configData);

      final result = await getSaveLocation(
        suggestedName: '${currentConfig.name}_config.json',
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'JSON配置文件',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );

      if (result != null) {
        final file = File(result.path);
        await file.writeAsString(jsonString);
        _showSuccessDialog('当前配置导出成功');
      }
    } catch (e) {
      _showErrorDialog('配置导出失败: $e');
    }
  }

  // 导出所有配置
  Future<void> _exportAllConfigs() async {
    try {
      final allConfigsData = _copyConfigs.map((config) => config.toJson()).toList();
      final jsonString = json.encode(allConfigsData);

      final result = await getSaveLocation(
        suggestedName: 'all_configs.json',
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'JSON配置文件',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );

      if (result != null) {
        final file = File(result.path);
        await file.writeAsString(jsonString);
        _showSuccessDialog('所有配置导出成功');
      }
    } catch (e) {
      _showErrorDialog('配置导出失败: $e');
    }
  }

  // 显示成功对话框
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成功'),
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

  // 显示大图对话框
  void _showImageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset(
                'lib/res/logo_check.png',
                fit: BoxFit.contain,
                width: 300,
                height: 300,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 打开配置管理子界面
  void _openConfigManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CopyConfigManagerScreen(
          copyConfigs: _copyConfigs,
          selectedIndex: _currentConfigIndex,
          onSelectConfig: (index) {
            setState(() {
              _currentConfigIndex = index;
              _updateControllers();
              _saveSettings();
            });
          },
          onEditConfig: (index) {
            setState(() {
              _currentConfigIndex = index;
              _updateControllers();
              _saveSettings();
            });
          },
        ),
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
        backgroundColor: MorandiColors.buttonPrimary.color,
        foregroundColor: MorandiColors.buttonText.color,
        title: Row(
          children: [
            const Text('文件拷贝管理器'),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showImageDialog(),
              child: SizedBox(
                height: kToolbarHeight * 0.8,
                width: kToolbarHeight * 0.8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                  'lib/res/logo_check.png',
                  fit: BoxFit.contain,
                ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 可滚动的主要内容区域
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA), // 浅灰色背景
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 拷贝配置区
                      _buildSection(
                        title: '拷贝配置',
                        backgroundColor: MorandiColors.configArea.color,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _currentConfigIndex,
                                    decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: MorandiColors.border.color),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: _copyConfigs.asMap().entries.map((entry) {
                                    return DropdownMenuItem<int>(
                                      value: entry.key,
                                      child: Text(
                                        entry.value.name,
                                        style: TextStyle(color: MorandiColors.textPrimary.color),
                                      ),
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
                                  style: TextStyle(color: MorandiColors.textPrimary.color),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildSmallButton(
                                icon: Icons.edit,
                                label: '重命名',
                                onPressed: _showRenameDialog,
                              ),
                              const SizedBox(width: 8),
                              _buildSmallButton(
                                icon: Icons.add,
                                label: '新增',
                                onPressed: _addNewConfig,
                              ),
                              const SizedBox(width: 8),
                              _buildSmallButton(
                                icon: Icons.delete,
                                label: '删除',
                                onPressed: () => _deleteConfig(_currentConfigIndex),
                                isDanger: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 第二排按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildSmallButton(
                                icon: Icons.manage_accounts,
                                label: '管理配置',
                                onPressed: _openConfigManager,
                              ),
                              const SizedBox(width: 8),
                              _buildSmallButton(
                                icon: Icons.import_export,
                                label: '导入',
                                onPressed: _importConfig,
                              ),
                              const SizedBox(width: 8),
                              _buildSmallButton(
                                icon: Icons.save_alt,
                                label: '导出',
                                onPressed: _showExportDialog,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 目录区
                    _buildSection(
                      title: '目录设置',
                      backgroundColor: MorandiColors.directoryArea.color,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 源目录选择
                          const Text(
                            '源目录',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: MorandiColors.border.color),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    hintText: '请输入或选择源目录',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: MorandiColors.textPrimary.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                label: '选择目录',
                                onPressed: _selectSourceDirectory,
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                label: '打开目录',
                                onPressed: _openSourceDirectory,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 目标目录选择
                          const Text(
                            '目标目录',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: MorandiColors.border.color),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    hintText: '请输入或选择目标目录',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: MorandiColors.textPrimary.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                label: '选择目录',
                                onPressed: _selectDestinationDirectory,
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                label: '打开目录',
                                onPressed: _openDestinationDirectory,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 屏蔽路径区
                    _buildSection(
                      title: '屏蔽路径',
                      backgroundColor: MorandiColors.excludeArea.color,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '设置需要屏蔽的文件或目录',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              Row(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.visibility,
                                    label: '更好的查看',
                                    onPressed: () => _openExcludedPathsScreen(),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.folder,
                                    label: '添加目录',
                                    onPressed: _addExcludedPath,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: Icons.file_copy,
                                    label: '添加文件',
                                    onPressed: _addExcludedFile,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (currentConfig.excludedPaths.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: MorandiColors.border.color),
                              ),
                              child: Text(
                                '没有设置屏蔽路径',
                                style: TextStyle(color: MorandiColors.textSecondary.color),
                              ),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: MorandiColors.border.color),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: currentConfig.excludedPaths.length,
                                itemBuilder: (context, index) {
                                  final excludedPath = currentConfig.excludedPaths[index];
                                  final relativePath = currentConfig.sourceDirectory != null
                                      ? path.relative(excludedPath, from: currentConfig.sourceDirectory!)
                                      : excludedPath;
                                  return ListTile(
                                    title: Text(
                                      relativePath,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: MorandiColors.textPrimary.color,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      onPressed: () => _removeExcludedPath(index),
                                      color: Colors.red[400],
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ),
            ),

            const SizedBox(height: 20),
            // 常驻的执行拷贝区
            _buildSection(
              title: '执行拷贝',
              backgroundColor: MorandiColors.executeArea.color,
              child: Column(
                children: [
                  // 操作区域 - 左侧单选框，右侧按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 删除目标目录选项（左侧）
                      Row(
                        children: [
                          Checkbox(
                            value: currentConfig.shouldDeleteDestDir,
                            onChanged: (value) {
                              setState(() {
                                currentConfig.shouldDeleteDestDir = value ?? false;
                              });
                              _saveSettings();
                            },
                            activeColor: MorandiColors.buttonPrimary.color,
                            checkColor: MorandiColors.buttonText.color,
                          ),
                          Text(
                            '拷贝前删除目标目录下的所有文件',
                            style: TextStyle(color: MorandiColors.textPrimary.color),
                          ),
                        ],
                      ),

                      // 拷贝按钮（右侧）
                      ElevatedButton.icon(
                        onPressed: _isCopying ? null : _copyFiles,
                        icon: const Icon(Icons.copy),
                        label: const Text('开始拷贝', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MorandiColors.buttonPrimary.color,
                          foregroundColor: MorandiColors.buttonText.color,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 拷贝状态
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      _copyStatus,
                      style: TextStyle(
                        fontSize: 16,
                        color: _isCopying ? MorandiColors.buttonPrimary.color : Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建功能区块
  Widget _buildSection({
    required String title,
    required Color backgroundColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MorandiColors.border.color),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: MorandiColors.textPrimary.color,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
  
  // 构建小按钮
  Widget _buildSmallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDense = true,
    bool isDanger = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDanger ? Colors.red[400] : MorandiColors.buttonSecondary.color,
        foregroundColor: isDanger ? Colors.white : MorandiColors.buttonText.color,
        padding: EdgeInsets.symmetric(horizontal: isDense ? 8 : 12, vertical: isDense ? 10 : 12),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
  
  // 构建操作按钮
  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 16) : null,
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: MorandiColors.buttonSecondary.color,
        foregroundColor: MorandiColors.buttonText.color,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
