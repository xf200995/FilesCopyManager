import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'colors.dart';

// 通配符路径匹配器
class PathMatcher {
  final String pattern;
  final String sourceDirectory;
  
  PathMatcher(this.pattern, this.sourceDirectory);
  
  // 检查文件路径是否匹配模式
  bool matches(String filePath) {
    if (pattern.isEmpty) return false;
    
    // 规范化路径
    final normalizedPattern = _normalizePath(pattern);
    final normalizedFilePath = _normalizePath(filePath);
    
    // 获取相对于源目录的路径
    final relativeFilePath = _getRelativePath(normalizedFilePath);
    if (relativeFilePath == null) {
      // 如果不在源目录下，尝试传统的前缀匹配
      return normalizedFilePath.startsWith(normalizedPattern);
    }
    
    // 使用新的通用匹配逻辑
    return _matchPattern(normalizedPattern, relativeFilePath);
  }
  
  // 通用匹配逻辑
  bool _matchPattern(String pattern, String relativeFilePath) {
    // 处理简单的递归文件模式：*.json（源目录及其所有子目录下的json文件）
    if (_isSimpleRecursivePattern(pattern)) {
      return _matchSimpleRecursivePattern(pattern, relativeFilePath);
    }
    
    // 处理更通用的模式
    final separator = pattern.contains('/') ? '/' : Platform.pathSeparator;
    final patternParts = pattern.split(separator);
    final filePathParts = relativeFilePath.split(Platform.pathSeparator);
    
    // 模式必须至少有一个部分
    if (patternParts.isEmpty) return false;
    
    // 检查是否是 * 开头的模式（相对于源目录）
    if (patternParts.first == '*') {
      // 去掉开头的 *
      final remainingPatternParts = patternParts.skip(1).toList();
      if (remainingPatternParts.isEmpty) return false;
      
      // 查找模式中最后一个部分是文件名模式
      final lastPatternPart = remainingPatternParts.last;
      final isFilePattern = lastPatternPart.startsWith('*.') || 
          lastPatternPart.endsWith('.*') || 
          lastPatternPart.contains('*');
      
      if (isFilePattern && remainingPatternParts.length >= 2) {
        // 模式类似 */dir/*.png：匹配 dir 目录及其所有子目录下的 png 文件
        final dirPatternParts = remainingPatternParts.sublist(0, remainingPatternParts.length - 1);
        final filePattern = remainingPatternParts.last;
        
        // 检查文件路径是否以指定的目录模式开头
        bool startsWithDirPattern = false;
        for (int i = 0; i <= filePathParts.length - dirPatternParts.length; i++) {
          bool dirMatch = true;
          for (int j = 0; j < dirPatternParts.length; j++) {
            if (!_matchPart(dirPatternParts[j], filePathParts[i + j])) {
              dirMatch = false;
              break;
            }
          }
          if (dirMatch) {
            startsWithDirPattern = true;
            break;
          }
        }
        
        if (!startsWithDirPattern) return false;
        
        // 检查文件名是否匹配
        final fileName = filePathParts.last;
        return _matchPart(filePattern, fileName);
      } else {
        // 从任意位置开始匹配剩余的模式
        return _matchFromPosition(remainingPatternParts, filePathParts, 0);
      }
    } else {
      // 从开头开始匹配
      return _matchFromPosition(patternParts, filePathParts, 0);
    }
  }
  
  // 从指定位置开始匹配模式
  bool _matchFromPosition(List<String> patternParts, List<String> filePathParts, int startPos) {
    // 遍历所有可能的起始位置
    for (int i = startPos; i <= filePathParts.length - patternParts.length; i++) {
      bool match = true;
      for (int j = 0; j < patternParts.length; j++) {
        if (!_matchPart(patternParts[j], filePathParts[i + j])) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }
  
  // 匹配单个部分
  bool _matchPart(String patternPart, String filePathPart) {
    // 处理 *.ext 模式
    if (patternPart.startsWith('*.')) {
      final extension = patternPart.substring(1);
      return filePathPart.endsWith(extension);
    }
    
    // 处理 * 通配符
    if (patternPart == '*') {
      return true;
    }
    
    // 处理 name.* 模式
    if (patternPart.endsWith('.*')) {
      final name = patternPart.substring(0, patternPart.length - 2);
      return filePathPart.startsWith(name + '.');
    }
    
    // 处理包含 * 的模式
    if (patternPart.contains('*')) {
      final regexPattern = patternPart
          .replaceAll('.', r'\.')
          .replaceAll('*', '.*');
      return RegExp('^$regexPattern\$').hasMatch(filePathPart);
    }
    
    // 精确匹配
    return patternPart == filePathPart;
  }
  
  // 检查是否是简单递归模式
  bool _isSimpleRecursivePattern(String pattern) {
    return pattern.startsWith('*.') && !pattern.contains('/') && !pattern.contains(Platform.pathSeparator);
  }
  
  // 匹配简单递归模式
  bool _matchSimpleRecursivePattern(String pattern, String relativeFilePath) {
    final extension = pattern.substring(1);
    return relativeFilePath.endsWith(extension);
  }
  
  // 规范化路径
  String _normalizePath(String filePath) {
    return path.normalize(filePath);
  }
  
  // 获取相对于源目录的路径
  String? _getRelativePath(String filePath) {
    try {
      final relative = path.relative(filePath, from: sourceDirectory);
      // 检查路径是否真的在源目录下（不以 .. 开头）
      if (relative.startsWith('..') || path.isAbsolute(relative)) {
        return null;
      }
      return relative;
    } catch (e) {
      return null;
    }
  }
}

// 拷贝日志条目类
class CopyLogEntry {
  final DateTime timestamp;
  final String sourcePath;
  final String destinationPath;
  final int fileSize;
  final bool success;
  final String? errorMessage;

  CopyLogEntry({
    required this.timestamp,
    required this.sourcePath,
    required this.destinationPath,
    required this.fileSize,
    required this.success,
    this.errorMessage,
  });

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'sourcePath': sourcePath,
      'destinationPath': destinationPath,
      'fileSize': fileSize,
      'success': success,
      'errorMessage': errorMessage,
    };
  }

  // 从JSON创建
  factory CopyLogEntry.fromJson(Map<String, dynamic> json) {
    return CopyLogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      sourcePath: json['sourcePath'],
      destinationPath: json['destinationPath'],
      fileSize: json['fileSize'],
      success: json['success'],
      errorMessage: json['errorMessage'],
    );
  }
}

// 拷贝状态类
class CopyState {
  bool isCopying;
  String copyStatus;
  bool hasCopyLog;

  CopyState({
    required this.isCopying,
    required this.copyStatus,
    required this.hasCopyLog,
  });
}

// 拷贝日志事件广播器
class CopyLogBroadcaster {
  static final CopyLogBroadcaster _instance = CopyLogBroadcaster._internal();
  factory CopyLogBroadcaster() => _instance;

  CopyLogBroadcaster._internal();

  final StreamController<CopyLogEntry> _logController = StreamController<CopyLogEntry>.broadcast();
  final StreamController<void> _clearController = StreamController<void>.broadcast();
  final ValueNotifier<CopyState> _stateNotifier = ValueNotifier<CopyState>(
    CopyState(isCopying: false, copyStatus: '', hasCopyLog: false),
  );

  Stream<CopyLogEntry> get logStream => _logController.stream;
  Stream<void> get clearStream => _clearController.stream;
  ValueNotifier<CopyState> get stateNotifier => _stateNotifier;

  void addLogEntry(CopyLogEntry entry) {
    _logController.add(entry);
  }

  void clearLogs() {
    _clearController.add(null);
  }

  void updateState(CopyState state) {
    _stateNotifier.value = state;
  }

  void dispose() {
    _logController.close();
    _clearController.close();
    _stateNotifier.dispose();
  }
}

// 排除路径子界面
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
  final Function(int) onCopyFiles;
  final Function(int) onToggleDeleteDestDir;
  final Function(int) onDeleteConfig;
  final VoidCallback onAddConfig;
  final bool isCopying;
  final String copyStatus;
  final bool hasCopyLog;
  final VoidCallback onShowCopyLog;
  final VoidCallback onRefresh;

  const CopyConfigManagerScreen({
    Key? key,
    required this.copyConfigs,
    required this.selectedIndex,
    required this.onSelectConfig,
    required this.onEditConfig,
    required this.onCopyFiles,
    required this.onToggleDeleteDestDir,
    required this.onDeleteConfig,
    required this.onAddConfig,
    required this.isCopying,
    required this.copyStatus,
    required this.hasCopyLog,
    required this.onShowCopyLog,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<CopyConfigManagerScreen> createState() => _CopyConfigManagerScreenState();
}

class _CopyConfigManagerScreenState extends State<CopyConfigManagerScreen> {
  late int _selectedIndex;
  Timer? _refreshTimer;
  StreamSubscription<CopyLogEntry>? _logSubscription;
  StreamSubscription<void>? _clearSubscription;
  late VoidCallback _stateListener;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    
    // 启动定时刷新，每500毫秒刷新一次
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        // 刷新状态
      });
    });
    
    // 监听拷贝日志事件
    _logSubscription = CopyLogBroadcaster().logStream.listen((entry) {
      setState(() {
        // 日志更新会触发UI刷新
      });
    });
    
    // 监听日志清除事件
    _clearSubscription = CopyLogBroadcaster().clearStream.listen((_) {
      setState(() {
        // 日志清除会触发UI刷新
      });
    });
    
    // 监听拷贝状态变化
    _stateListener = () {
      setState(() {
        // 状态变化会触发UI刷新
      });
    };
    CopyLogBroadcaster().stateNotifier.addListener(_stateListener);
  }

  @override
  void didUpdateWidget(CopyConfigManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 确保 _selectedIndex 始终在有效范围内
    if (widget.copyConfigs.length != oldWidget.copyConfigs.length) {
      setState(() {
        if (widget.copyConfigs.isEmpty) {
          _selectedIndex = -1;
        } else if (_selectedIndex >= widget.copyConfigs.length) {
          _selectedIndex = widget.copyConfigs.length - 1;
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _logSubscription?.cancel();
    _clearSubscription?.cancel();
    CopyLogBroadcaster().stateNotifier.removeListener(_stateListener);
    super.dispose();
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
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        widget.onDeleteConfig(index);
                                      },
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
              visible: _selectedIndex >= 0 && _selectedIndex < widget.copyConfigs.length,
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
                        Navigator.pop(context);
                        widget.onAddConfig();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MorandiColors.buttonSecondary.color,
                        foregroundColor: MorandiColors.buttonText.color,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('新增配置'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (_selectedIndex >= 0 && _selectedIndex < widget.copyConfigs.length) {
                          widget.onEditConfig(_selectedIndex);
                          Navigator.pop(context);
                        }
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
            // 执行拷贝区
            Visibility(
              visible: _selectedIndex >= 0 && _selectedIndex < widget.copyConfigs.length,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(top: 16.0),
                decoration: BoxDecoration(
                  color: MorandiColors.executeArea.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 删除目标目录选项（左侧）
                        Row(
                          children: [
                            Checkbox(
                              value: _selectedIndex >= 0 && _selectedIndex < widget.copyConfigs.length 
                                  ? widget.copyConfigs[_selectedIndex].shouldDeleteDestDir 
                                  : false,
                              onChanged: (value) {
                                if (_selectedIndex >= 0 && _selectedIndex < widget.copyConfigs.length) {
                                  widget.onToggleDeleteDestDir(_selectedIndex);
                                }
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
                          onPressed: widget.isCopying || _selectedIndex < 0 || _selectedIndex >= widget.copyConfigs.length 
                              ? null 
                              : () => widget.onCopyFiles(_selectedIndex),
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
                         widget.copyStatus,
                         style: TextStyle(
                           fontSize: 16,
                           color: widget.isCopying ? MorandiColors.buttonPrimary.color : Colors.green[600],
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                     ),
                     const SizedBox(height: 12),
                     
                     // 查看日志按钮
                     Visibility(
                       visible: !widget.isCopying && widget.hasCopyLog,
                       child: Align(
                         alignment: Alignment.center,
                         child: ElevatedButton.icon(
                           onPressed: widget.onShowCopyLog,
                           icon: const Icon(Icons.list),
                           label: const Text('查看拷贝日志', style: TextStyle(fontSize: 14)),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: MorandiColors.buttonSecondary.color,
                             foregroundColor: MorandiColors.buttonText.color,
                             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(8),
                             ),
                           ),
                         ),
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
  void _sortExcludedPaths() {
    setState(() {
      widget.config.excludedPaths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

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
          _sortExcludedPaths();
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
          _sortExcludedPaths();
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

  void _showCustomRulesDialog() {
    final TextEditingController ruleController = TextEditingController();
    final List<String> tempRules = List.from(widget.config.excludedPaths);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('自定义排除规则'),
            content: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 规则说明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MorandiColors.executeArea.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '规则说明：',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: MorandiColors.textPrimary.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRuleItem('*.json', '排除源目录及其所有子目录下的 .json 文件'),
                        _buildRuleItem('*/a/*.meta', '排除a目录下的所有 .meta 文件'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 添加新规则
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ruleController,
                          decoration: InputDecoration(
                            hintText: '输入规则，如：*.json',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (ruleController.text.trim().isNotEmpty) {
                            final newRule = ruleController.text.trim();
                            if (!tempRules.contains(newRule)) {
                              setDialogState(() {
                                tempRules.add(newRule);
                              });
                              ruleController.clear();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MorandiColors.buttonPrimary.color,
                          foregroundColor: MorandiColors.buttonText.color,
                        ),
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 规则列表
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MorandiColors.border.color),
                      ),
                      child: tempRules.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '暂无自定义规则',
                                  style: TextStyle(
                                    color: MorandiColors.textSecondary.color,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: tempRules.length,
                              itemBuilder: (context, index) {
                                final rule = tempRules[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    rule,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        tempRules.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    widget.config.excludedPaths.clear();
                    widget.config.excludedPaths.addAll(tempRules);
                    _sortExcludedPaths();
                  });
                  widget.onConfigChanged();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MorandiColors.buttonPrimary.color,
                  foregroundColor: MorandiColors.buttonText.color,
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRuleItem(String rule, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: MorandiColors.buttonPrimary.color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              rule,
              style: TextStyle(
                color: MorandiColors.buttonText.color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: MorandiColors.textPrimary.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _sortExcludedPaths();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排除路径管理'),
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
                  icon: Icons.edit,
                  label: '自定义规则',
                  onPressed: _showCustomRulesDialog,
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
            const SizedBox(height: 16),

            // 排除路径列表
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
                      '排除路径列表',
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
                              '没有设置排除路径',
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
                            
                            // 判断是否是通配符规则
                            final isWildcardRule = excludedPath.startsWith('*.') || 
                                excludedPath.startsWith('*/') ||
                                excludedPath.startsWith('*\\');
                            
                            String displayName;
                            String displaySubtitle;
                            IconData displayIcon;
                            
                            if (isWildcardRule) {
                              // 通配符规则
                              displayName = excludedPath;
                              displaySubtitle = '自定义规则';
                              displayIcon = Icons.rule;
                            } else {
                              // 普通路径
                              final relativePath = widget.config.sourceDirectory != null
                                  ? path.relative(excludedPath, from: widget.config.sourceDirectory!)
                                  : excludedPath;
                              displayName = path.basename(excludedPath);
                              displaySubtitle = relativePath;
                              displayIcon = FileSystemEntity.typeSync(excludedPath) == FileSystemEntityType.directory
                                  ? Icons.folder
                                  : Icons.file_copy;
                            }
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  displayIcon,
                                  color: isWildcardRule 
                                      ? Colors.orange 
                                      : MorandiColors.buttonPrimary.color,
                                ),
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: MorandiColors.textPrimary.color,
                                  ),
                                ),
                                subtitle: Text(
                                  displaySubtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isWildcardRule 
                                        ? Colors.orange[700] 
                                        : MorandiColors.textSecondary.color,
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
      home: const SplashScreen(),
    );
  }
}

// 启动页面
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 延迟一点时间再跳转到配置管理页面
    Future.delayed(const Duration(milliseconds: 500), () {
      // 直接打开配置管理页面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FileCopyManagerScreen(),
        ),
      ).then((_) {
        // 进入主页后立即打开配置管理页面
        if (context.mounted) {
          // 这里需要调用主页的_openConfigManager方法
        }
      });
    });

    // 显示启动画面
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '文件拷贝管理器',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              color: MorandiColors.buttonPrimary.color,
            ),
          ],
        ),
      ),
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
  final List<CopyLogEntry> _copyLog = [];


  
  // 文本编辑控制器
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _configNameController = TextEditingController();
  
  // 事件订阅
  StreamSubscription<CopyLogEntry>? _logSubscription;
  StreamSubscription<void>? _clearSubscription;
  
  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    _configNameController.dispose();
    _logSubscription?.cancel();
    _clearSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    // 监听拷贝日志事件
    _logSubscription = CopyLogBroadcaster().logStream.listen((entry) {
      setState(() {
        // 日志更新会触发UI刷新
      });
    });
    
    // 监听日志清除事件
    _clearSubscription = CopyLogBroadcaster().clearStream.listen((_) {
      setState(() {
        // 日志清除会触发UI刷新
      });
    });
    
    // 启动时自动打开配置管理页面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openConfigManager();
    });
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
      
      // 对每个配置的排除路径进行排序
      for (final config in _copyConfigs) {
        config.excludedPaths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
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
          _sortExcludedPaths();
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
          _sortExcludedPaths();
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

  void _sortExcludedPaths() {
    setState(() {
      _copyConfigs[_currentConfigIndex].excludedPaths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  void _showCustomRulesDialog() {
    final TextEditingController ruleController = TextEditingController();
    final List<String> tempRules = List.from(_copyConfigs[_currentConfigIndex].excludedPaths);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('自定义排除规则'),
            content: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 规则说明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MorandiColors.executeArea.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '规则说明：',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: MorandiColors.textPrimary.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRuleItem('*.json', '排除源目录及其所有子目录下的 .json 文件'),
                        _buildRuleItem('*/a/*.meta', '排除a目录下的所有 .meta 文件'),
                        _buildRuleItem('*/raw-assets/*.png', '排除raw-assets目录及其子目录下的 .png 文件'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 添加新规则
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ruleController,
                          decoration: InputDecoration(
                            hintText: '输入规则，如：*.json',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (ruleController.text.trim().isNotEmpty) {
                            final newRule = ruleController.text.trim();
                            if (!tempRules.contains(newRule)) {
                              setDialogState(() {
                                tempRules.add(newRule);
                              });
                              ruleController.clear();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MorandiColors.buttonPrimary.color,
                          foregroundColor: MorandiColors.buttonText.color,
                        ),
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 规则列表
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MorandiColors.border.color),
                      ),
                      child: tempRules.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '没有设置规则',
                                  style: TextStyle(color: MorandiColors.textSecondary.color),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: tempRules.length,
                              itemBuilder: (context, index) {
                                final rule = tempRules[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    rule,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        tempRules.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _copyConfigs[_currentConfigIndex].excludedPaths.clear();
                    _copyConfigs[_currentConfigIndex].excludedPaths.addAll(tempRules);
                    _sortExcludedPaths();
                  });
                  _saveSettings();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MorandiColors.buttonPrimary.color,
                  foregroundColor: MorandiColors.buttonText.color,
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRuleItem(String rule, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: MorandiColors.buttonPrimary.color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              rule,
              style: TextStyle(
                color: MorandiColors.buttonText.color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: MorandiColors.textPrimary.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeExcludedPath(int index) {
    setState(() {
      _copyConfigs[_currentConfigIndex].excludedPaths.removeAt(index);
    });
    _saveSettings();
  }

  bool _shouldExclude(String filePath, List<String> excludedPaths, String sourceDirectory) {
    return excludedPaths.any((excluded) {
      try {
        final matcher = PathMatcher(excluded, sourceDirectory);
        return matcher.matches(filePath);
      } catch (e) {
        // 如果匹配器失败，回退到传统的前缀匹配
        return filePath.startsWith(excluded);
      }
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
    _copyLog.clear();
    CopyLogBroadcaster().clearLogs();
    CopyLogBroadcaster().updateState(CopyState(
      isCopying: _isCopying,
      copyStatus: _copyStatus,
      hasCopyLog: _copyLog.isNotEmpty,
    ));

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
        CopyLogBroadcaster().updateState(CopyState(
          isCopying: _isCopying,
          copyStatus: _copyStatus,
          hasCopyLog: _copyLog.isNotEmpty,
        ));
        
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
      CopyLogBroadcaster().updateState(CopyState(
        isCopying: _isCopying,
        copyStatus: _copyStatus,
        hasCopyLog: _copyLog.isNotEmpty,
      ));
    } catch (e) {
      setState(() {
        _copyStatus = '拷贝失败: $e';
        _copyLog.add(CopyLogEntry(
          timestamp: DateTime.now(),
          sourcePath: '全局错误',
          destinationPath: '全局错误',
          fileSize: 0,
          success: false,
          errorMessage: '$e',
        ));
      });
      CopyLogBroadcaster().updateState(CopyState(
        isCopying: _isCopying,
        copyStatus: _copyStatus,
        hasCopyLog: _copyLog.isNotEmpty,
      ));
    } finally {
      setState(() {
        _isCopying = false;
      });
      // 延迟一点时间再更新状态，确保UI有足够时间刷新
      Future.delayed(const Duration(milliseconds: 100), () {
        CopyLogBroadcaster().updateState(CopyState(
          isCopying: _isCopying,
          copyStatus: _copyStatus,
          hasCopyLog: _copyLog.isNotEmpty,
        ));
      });
    }
  }

  Future<void> _copyDirectory(Directory source, CopyConfig config) async {
    final List<FileSystemEntity> entities = source.listSync(recursive: false);

    for (var entity in entities) {
      final relativePath = path.relative(entity.path, from: config.sourceDirectory!);
      final destPath = path.join(config.destinationDirectory!, relativePath);

      if (_shouldExclude(entity.path, config.excludedPaths, config.sourceDirectory!)) {
        setState(() {
          _copyStatus = '跳过: $relativePath';
        });
        CopyLogBroadcaster().updateState(CopyState(
          isCopying: _isCopying,
          copyStatus: _copyStatus,
          hasCopyLog: _copyLog.isNotEmpty,
        ));
        continue;
      }

      setState(() {
        _copyStatus = '正在拷贝: $relativePath';
      });
      CopyLogBroadcaster().updateState(CopyState(
        isCopying: _isCopying,
        copyStatus: _copyStatus,
        hasCopyLog: _copyLog.isNotEmpty,
      ));

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
        
        try {
            final fileSize = await entity.length();
            await entity.copy(destPath);
            
            final logEntry = CopyLogEntry(
              timestamp: DateTime.now(),
              sourcePath: entity.path,
              destinationPath: destPath,
              fileSize: fileSize,
              success: true,
            );
            
            setState(() {
              _copyLog.add(logEntry);
            });
            
            // 广播日志条目
            CopyLogBroadcaster().addLogEntry(logEntry);
          } catch (e) {
            final logEntry = CopyLogEntry(
              timestamp: DateTime.now(),
              sourcePath: entity.path,
              destinationPath: destPath,
              fileSize: 0,
              success: false,
              errorMessage: '$e',
            );
            
            setState(() {
              _copyLog.add(logEntry);
            });
            
            // 广播日志条目
            CopyLogBroadcaster().addLogEntry(logEntry);
          }
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

  // 显示拷贝日志
  void _showCopyLog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拷贝日志'),
        content: Container(
          width: double.maxFinite,
          height: 500,
          child: ListView.builder(
            itemCount: _copyLog.length,
            itemBuilder: (context, index) {
              final entry = _copyLog[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.success ? '成功' : '失败',
                            style: TextStyle(
                              color: entry.success ? Colors.green[600] : Colors.red[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${entry.timestamp.hour}:${entry.timestamp.minute}:${entry.timestamp.second}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('源文件: ${entry.sourcePath}'),
                      Text('目标文件: ${entry.destinationPath}'),
                      if (entry.fileSize > 0) 
                        Text('文件大小: ${(entry.fileSize / 1024).toStringAsFixed(2)} KB'),
                      if (!entry.success && entry.errorMessage != null) 
                        Text(
                          '错误信息: ${entry.errorMessage}',
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
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

  // 自动命名函数，处理同名配置
  String _generateUniqueName(List<CopyConfig> configs, String baseName) {
    if (configs.isEmpty) return baseName;
    
    // 检查是否有同名配置
    final count = configs.where((config) => config.name.startsWith(baseName)).length;
    
    if (count == 0) return baseName;
    return '${baseName}_${count + 1}';
  }

  // 打开配置管理子界面
  void _openConfigManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ValueListenableBuilder<CopyState>(
          valueListenable: CopyLogBroadcaster().stateNotifier,
          builder: (context, state, child) {
            return CopyConfigManagerScreen(
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
              onCopyFiles: (index) async {
                setState(() {
                  _currentConfigIndex = index;
                  _updateControllers();
                });
                await _copyFiles();
              },
              onToggleDeleteDestDir: (index) {
                setState(() {
                  _copyConfigs[index].shouldDeleteDestDir = !_copyConfigs[index].shouldDeleteDestDir;
                  _saveSettings();
                });
              },
              onDeleteConfig: (index) {
                setState(() {
                  _copyConfigs.removeAt(index);
                  if (_currentConfigIndex >= _copyConfigs.length) {
                    _currentConfigIndex = _copyConfigs.length > 0 ? _copyConfigs.length - 1 : 0;
                  }
                  _saveSettings();
                });
              },
              onAddConfig: () {
                // 实现新增配置逻辑
                setState(() {
                  // 生成唯一名称
                  final uniqueName = _generateUniqueName(_copyConfigs, '新配置');
                  
                  // 创建新的配置
                  _copyConfigs.add(CopyConfig(
                    name: uniqueName,
                    sourceDirectory: '',
                    destinationDirectory: '',
                    excludedPaths: [],
                    shouldDeleteDestDir: false,
                  ));
                  _currentConfigIndex = _copyConfigs.length - 1;
                  _updateControllers();
                  _saveSettings();
                });
              },
              isCopying: _isCopying,
              copyStatus: _copyStatus,
              hasCopyLog: _copyLog.isNotEmpty,
              onShowCopyLog: _showCopyLog,
              onRefresh: () {
                setState(() {
                  // 刷新状态
                });
              },
            );
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

                    // 排除路径区
                    _buildSection(
                      title: '排除路径',
                      backgroundColor: MorandiColors.excludeArea.color,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '设置需要排除的文件或目录',
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
                                    icon: Icons.edit,
                                    label: '自定义规则',
                                    onPressed: _showCustomRulesDialog,
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
                                '没有设置排除路径',
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
                                
                                // 判断是否是通配符规则
                                final isWildcardRule = excludedPath.startsWith('*.') || 
                                    excludedPath.startsWith('*/') ||
                                    excludedPath.startsWith('*\\');
                                
                                String displayText;
                                
                                if (isWildcardRule) {
                                  // 通配符规则 - 直接显示规则
                                  displayText = excludedPath;
                                } else {
                                  // 普通路径 - 显示相对路径
                                  final relativePath = currentConfig.sourceDirectory != null
                                      ? path.relative(excludedPath, from: currentConfig.sourceDirectory!)
                                      : excludedPath;
                                  displayText = relativePath;
                                }
                                
                                return ListTile(
                                  title: Text(
                                    displayText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isWildcardRule 
                                          ? Colors.orange[700] 
                                          : MorandiColors.textPrimary.color,
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
                  const SizedBox(height: 12),
                  
                  // 查看日志按钮
                  Visibility(
                    visible: !_isCopying && _copyLog.isNotEmpty,
                    child: Align(
                      alignment: Alignment.center,
                      child: ElevatedButton.icon(
                        onPressed: _showCopyLog,
                        icon: const Icon(Icons.list),
                        label: const Text('查看拷贝日志', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MorandiColors.buttonSecondary.color,
                          foregroundColor: MorandiColors.buttonText.color,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
