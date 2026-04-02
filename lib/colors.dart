// 莫兰迪色系配置文件
import 'package:flutter/material.dart';
enum MorandiColors {
  // 拷贝配置区 - 浅蓝灰色
  configArea(0xFFE0E6ED),
  
  // 目录区 - 浅灰绿色
  directoryArea(0xFFE4E9E4),
  
  // 屏蔽路径区 - 浅粉灰色
  excludeArea(0xFFEDE3E4),
  
  // 执行区 - 浅黄灰色
  executeArea(0xFFF1EDE0),
  
  // 边框颜色
  border(0xFFD1D5DB),
  
  // 文字颜色
  textPrimary(0xFF374151),
  textSecondary(0xFF6B7280),
  
  // 按钮颜色
  buttonPrimary(0xFF93C5FD),
  buttonSecondary(0xFFBFDBFE),
  buttonText(0xFF1E40AF);
  
  final int value;
  const MorandiColors(this.value);
  
  Color get color => Color(value);
}
