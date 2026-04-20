# Flutter Windows 应用分发指南

## 问题原因
您的应用在其他Windows 10电脑上无法启动，最常见的原因是：
**只拷贝了.exe文件，而没有拷贝整个Release文件夹中的所有依赖文件！**

## 正确的打包和分发方法

### 1. 构建Release版本
我们已经成功构建了Release版本，构建产物位于：
```
build\windows\x64\runner\Release\
```

### 2. 打包整个Release文件夹
**重要：不要只拷贝.exe文件！** 必须将整个 `Release` 文件夹打包分发。

Release文件夹中包含的所有必需文件：
```
Release/
├── data/
│   ├── flutter_assets/       # Flutter资源文件
│   ├── app.so                  # 应用代码
│   └── icudtl.dat              # Unicode数据文件
├── file_selector_windows_plugin.dll  # 插件依赖
├── files_copy_manager.exe      # 主程序（不要只拷贝这个！）
├── flutter_windows.dll        # Flutter引擎
└── url_launcher_windows_plugin.dll  # 插件依赖
```

### 3. 分发方法
将整个 `Release` 文件夹：
- 压缩成zip文件发送给用户
- 或者直接复制整个文件夹到目标电脑

### 4. 在目标电脑上运行
1. 解压或复制整个Release文件夹
2. 双击 `files_copy_manager.exe` 运行

## 其他可能的问题

### 目标电脑缺少Visual C++ Redistributable
如果目标电脑没有安装Visual C++ Redistributable，应用也可能无法启动。

**解决方法：**
在目标电脑上下载并安装 [Microsoft Visual C++ Redistributable for Visual Studio 2015-2022](https://aka.ms/vs/17/release/vc_redist.x64.exe)

### 防火墙或杀毒软件阻止
有些杀毒软件可能会阻止未知的.exe文件运行。

**解决方法：**
- 暂时禁用杀毒软件测试
- 将应用添加到杀毒软件白名单

## 验证打包是否正确
在目标电脑上，确保：
1. Release文件夹中包含所有文件（不仅仅是.exe）
2. 文件夹结构保持完整
3. 没有缺失任何.dll或data文件夹中的文件

## 重新构建命令
如果需要重新构建Release版本，运行：
```bash
flutter clean
flutter build windows --release
```

构建完成后，完整的应用就在 `build\windows\x64\runner\Release\` 文件夹中。
