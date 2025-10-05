// 顶部导入区域（添加 compute）
import 'package:flutter/material.dart';
import 'file_picker_dialog.dart';
import 'regex_picker_dialog.dart';
import '../utils/app_text_styles.dart';
import 'common_components.dart';
import '../utils/byte_length_input_formatter.dart';
import 'dart:async';
import '../utils/file_utils.dart';
import '../utils/regex_utils.dart';

// 顶部：新增可选 Controller 类
// TextAreaRegexController 类
class TextAreaRegexController extends ChangeNotifier {
  String _originalText = '';
  String _regex = '';
  bool _regexEnabled = false;
  
  // 新增：当前显示文本（可能已应用正则）
  String _text = '';
  
  String get originalText => _originalText;
  String get regex => _regex;
  bool get regexEnabled => _regexEnabled;
  String get text => _text; // 新增：对外只读访问当前显示文本

  void _setInternal({
    required String text,            // 新增：当前显示文本
    required String originalText,
    required String regex,
    required bool regexEnabled,
  }) {
    _text = text;                    // 新增：同步当前显示文本
    _originalText = originalText;
    _regex = regex;
    _regexEnabled = regexEnabled;
    notifyListeners();
  }
}

// TextAreaRegexInput 构造与字段：移除 onOutputChanged，仅保留可选 controller
class TextAreaRegexInput extends StatefulWidget {
  final String? initialText;
  final String? initialFilePath;
  final String? initialRegex;
  final FormFieldValidator<String>? mainValidator;
  final String mainLabel;
  final String mainHint;
  final Widget? rowPrefix;
  final TextAreaRegexController? controller; // 保留：外部读取入口

  const TextAreaRegexInput({
    Key? key,
    this.initialText,
    this.initialFilePath,
    this.initialRegex,
    this.mainValidator,
    this.mainLabel = '主内容',
    this.mainHint = '请输入内容或粘贴文本',
    this.rowPrefix,
    this.controller,
  }) : super(key: key);

  @override
  State<TextAreaRegexInput> createState() => _TextAreaRegexInputState();
}

// _TextAreaRegexInputState 类：_emitOutput 方法
// _TextAreaRegexInputState：_updateController 同步 text/regexEnabled
class _TextAreaRegexInputState extends State<TextAreaRegexInput> {
  late final TextEditingController _textController;
  late final TextEditingController _regexController;
  late var _regexValidationStates = false;
  late var _originalTexts = "";
  // 新增：文件读取订阅与取消任务句柄
  StreamSubscription<FileReadProgress>? _fileReadSub;
  CancelableFileRead? _fileTask;
  bool _isReading = false;
  int _processedLines = 0;
  String _fileContentBuffer = '';
  final FocusNode _textFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: ByteLimitFormatter.truncateUtf8(widget.initialText ?? '', 10240),
    );
    _regexController = TextEditingController(
      text: ByteLimitFormatter.truncateUtf8(widget.initialRegex ?? '', 10240),
    );
    _originalTexts = _textController.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateController());
    if ((widget.initialFilePath ?? '').isNotEmpty && _textController.text.isEmpty) {
      _readFromFile(widget.initialFilePath!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _emitOutput();
      });
    }
  }

  @override
  void dispose() {
    _fileReadSub?.cancel();
    _fileTask?.cancel();
    _textController.dispose();
    _regexController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _updateController() {
    widget.controller?._setInternal(
      text: _textController.text, // 新增：当前显示文本
      originalText: _originalTexts.isNotEmpty ? _originalTexts : _textController.text,
      regex: _regexController.text.trim(),
      regexEnabled: _regexValidationStates,
    );
  }

  void _emitOutput() {
    _updateController();
  }

  // 方法：文件选择与读取
  Future<void> _openFilePicker() async {
    final selectedPath = await FilePickerDialog.pickFile(
      context: context,
      title: '选择文件',
      initialPath: widget.initialFilePath ?? '',
    );
    if (selectedPath != null && selectedPath.isNotEmpty) {
      // 直接开始读取，不使用 LoadingDialog
      _readFromFile(selectedPath);
    }
  }

  // 方法：文件读取后把重处理放到后台Isolate
  Future<void> _readFromFile(String path) async {
    try {
      await _fileReadSub?.cancel();
      _fileTask?.cancel();
      _fileReadSub = null;
      _fileTask = null;
  
      if (mounted) {
        setState(() {
          _isReading = true;
          _processedLines = 0;
          _fileContentBuffer = '';
          _textController.text = '';
        });
      }
  
      final pattern = _regexController.text.trim();
      final task = FileUtils.readWithProgressCancelable(
        path: path,
        pattern: pattern.isEmpty ? null : pattern,
        maxBytes: FileUtils.defaultMaxBytes,
        largeThresholdBytes: FileUtils.defaultLargeThresholdBytes,
        reportEveryBytes: FileUtils.defaultReportEveryBytes,
      );
  
      _fileTask = task;
      _fileReadSub = task.stream.listen(
        (p) {
          if (!mounted) return;
          if (p.deltaText.isNotEmpty) {
            _fileContentBuffer += p.deltaText;
          }
          // 移除文本末尾状态行，仅更新正文内容
          _textController.text = _fileContentBuffer;
          _scrollToEnd();
          // 使用 setState 驱动后缀中的行号刷新
          if (mounted) {
            setState(() {
              _processedLines = p.linesRead;
            });
          }
  
          if (p.done) {
            setState(() {
              _isReading = false;
            });
            _emitOutput();
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _isReading = false;
          });
        },
        cancelOnError: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isReading = false;
      });
    }
  }

  // 显示正则表达式选择对话框
  void _showRegexPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RegexPickerDialog(
          initialValue: widget.initialRegex,
          onRegexSelected: (selectedRegex) {
            setState(() {
              _regexController.text = selectedRegex;
            });
          },
        );
      },
    );
  }

  void _scrollToEnd() {
    final end = _textController.text.length;
    if (!_textFocusNode.hasFocus) {
      _textFocusNode.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textController.selection = TextSelection.collapsed(offset: end);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.rowPrefix != null) ...[
              widget.rowPrefix!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextFormField(
                controller: _regexController,
                inputFormatters: const [ByteLimitFormatter(10240)],
                onChanged: (_) => _emitOutput(), // 新增：正则文本变化时同步
                decoration: AppTextStyles.getInputDecoration(
                  '正则表达式',
                  '请输入正则表达式，并选中输入框右侧按钮应用/取消',
                  suffixIconData: _regexValidationStates ? Icons.check_circle : Icons.radio_button_unchecked,
                  suffixIconColor: _regexValidationStates ? Colors.green.shade600 : Colors.grey.shade400,
                  onTap: () {
                    setState(() {
                      final isRegexValid = _regexController.text.isNotEmpty == true;
                      final isInputValid = _textController.text.isNotEmpty == true;
                      if (isRegexValid && isInputValid) {
                        final newState = !_regexValidationStates;
                        _regexValidationStates = newState;
                        if (newState) {
                          final originalText = _textController.text;
                          _originalTexts = originalText;
                          final pattern = _regexController.text.trim();
                          final processed = RegexUtils.extractGroup1AcrossLines(originalText, pattern);
                          _textController.text = processed;
                          _emitOutput();
                        } else {
                          final originalText = _originalTexts;
                          _textController.text = originalText;
                          _emitOutput();
                        }
                      } else {
                        _regexValidationStates = false;
                        _updateController();
                      }
                    });
                  }
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: AppTextStyles.inputFieldHeight,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showRegexPickerDialog();
                },
                icon: const Icon(Icons.pattern, size: 16),
                label: const Text('正则', style: TextStyle(fontSize: 12)),
                style: CommonComponents.getButtonStyle(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
            validator: widget.mainValidator,
            controller: _textController,
            focusNode: _textFocusNode,
            maxLines: 5,
            minLines: 3,
            onChanged: (_) {
              if (!_regexValidationStates) {
                _originalTexts = _textController.text;
              }
              _emitOutput();
            },
            inputFormatters: const [ByteLimitFormatter(10240)],
            decoration: AppTextStyles.getInputDecoration(
              widget.mainLabel,
              widget.mainHint,
              suffixIconData: _isReading ? null : Icons.file_open,
              suffixIconColor: Colors.cyan.shade700,
              onTap: _openFilePicker,
              isMultiline: true,
              suffixIconWidget: _isReading ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 4),
                  Text('$_processedLines', style: TextStyle(fontSize: 8, color: Colors.cyan.shade700)),
                ],
              ) : null,
            ),
          ),
      ],
    );
  }
}