import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/regex_config_loader.dart';
import '../utils/app_text_styles.dart';

class RegexPickerDialog extends StatefulWidget {
  final String? initialValue;
  final Function(String) onRegexSelected;

  const RegexPickerDialog({
    Key? key,
    this.initialValue,
    required this.onRegexSelected,
  }) : super(key: key);

  @override
  State<RegexPickerDialog> createState() => _RegexPickerDialogState();
}

class _RegexPickerDialogState extends State<RegexPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  
  String? _selectedRegex;
  String _searchQuery = '';
  List<RegexPattern> _allPatterns = [];
  Map<String, List<RegexPattern>> _categorizedPatterns = {};
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedRegex = widget.initialValue;
    _loadPatterns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatterns() async {
    try {
      final patterns = await RegexConfigLoader.instance.loadPatterns();
      final categorized = await RegexConfigLoader.instance.loadCategorizedPatterns();
      
      setState(() {
        _allPatterns = patterns;
        _categorizedPatterns = categorized;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('加载正则表达式配置失败: $e');
    }
  }

  List<RegexPattern> get _filteredPatterns {
    List<RegexPattern> patterns = _selectedCategory != null 
        ? _categorizedPatterns[_selectedCategory] ?? []
        : _allPatterns;
    
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      patterns = patterns.where((pattern) =>
          pattern.name.toLowerCase().contains(lowerQuery) ||
          pattern.description.toLowerCase().contains(lowerQuery) ||
          pattern.pattern.toLowerCase().contains(lowerQuery)
      ).toList();
    }
    
    return patterns;
  }

  void _selectRegex(String pattern) {
    setState(() {
      _selectedRegex = pattern;
    });
  }

  void _testRegex() {
    if (_selectedRegex?.isEmpty ?? true) {
      _showMessage('请先选择一个正则表达式');
      return;
    }
    showDialog(context: context, builder: (context) => RegexTestDialog(pattern: _selectedRegex!));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        height: 650,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSearchAndFilter(),
            const SizedBox(height: 16),
            _buildPatternsHeader(),
            const SizedBox(height: 8),
            Expanded(child: _buildPatternsList()),
            const SizedBox(height: 20),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.pattern, color: Colors.blue),
        const SizedBox(width: 8),
        const Text('正则表达式选择器', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: AppTextStyles.getInputDecoration(
              '搜索正则表达式...', '请输入正则表达式',
              prefixIconData: Icons.search
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(labelText: '分类', border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('全部分类')),
              ..._categorizedPatterns.keys.map((category) =>
                  DropdownMenuItem<String>(value: category, child: Text(category))),
            ],
            onChanged: (value) => setState(() => _selectedCategory = value),
          ),
        ),
      ],
    );
  }

  Widget _buildPatternsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('预定义模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (_selectedCategory != null)
              Chip(
                label: Text(_selectedCategory!),
                onDeleted: () => setState(() => _selectedCategory = null),
              ),
            const Spacer(),
            // 预览选中的正则表达式
            if (_selectedRegex != null && _selectedRegex!.isNotEmpty)
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _selectedRegex!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _testRegex,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('测试'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatternsList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _filteredPatterns.isEmpty
                ? const Center(child: Text('没有找到匹配的正则表达式', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _filteredPatterns.length,
                    itemBuilder: (context, index) => _buildPatternItem(_filteredPatterns[index]),
                  ),
          );
  }

  Widget _buildPatternItem(RegexPattern pattern) {
    final isSelected = _selectedRegex == pattern.pattern;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade50 : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                pattern.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.green.shade700 : null,
                ),
              ),
            ),
            if (_selectedCategory == null) _buildCategoryChip(pattern.category),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pattern.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            _buildPatternCode(pattern.pattern),
            Text('示例: ${pattern.example}', style: TextStyle(fontSize: 11, color: Colors.green.shade600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pattern.pattern));
                _showMessage('已复制到剪贴板');
              },
            ),
            if (isSelected) Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
          ],
        ),
        onTap: () => _selectRegex(pattern.pattern),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(category, style: const TextStyle(fontSize: 10)),
    );
  }

  Widget _buildPatternCode(String pattern) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pattern,
        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _selectedRegex?.isNotEmpty == true
              ? () {
                  widget.onRegexSelected(_selectedRegex!);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// 正则表达式测试对话框
class RegexTestDialog extends StatefulWidget {
  final String pattern;

  const RegexTestDialog({Key? key, required this.pattern}) : super(key: key);

  @override
  State<RegexTestDialog> createState() => _RegexTestDialogState();
}

class _RegexTestDialogState extends State<RegexTestDialog> {
  final TextEditingController _testController = TextEditingController();
  String? _testResult;
  bool _isMatch = false;

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  void _testPattern() {
    final testText = _testController.text;
    if (testText.isEmpty) {
      setState(() {
        _testResult = '请输入测试文本';
        _isMatch = false;
      });
      return;
    }

    try {
      final regex = RegExp(widget.pattern);
      final matches = regex.hasMatch(testText);
      setState(() {
        _isMatch = matches;
        _testResult = matches ? '✅ 匹配成功' : '❌ 不匹配';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ 正则表达式格式错误: $e';
        _isMatch = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('测试正则表达式'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('正则表达式:', style: TextStyle(color: Colors.grey.shade600)),
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(widget.pattern, style: const TextStyle(fontFamily: 'monospace')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _testController,
            decoration: const InputDecoration(labelText: '测试文本', border: OutlineInputBorder()),
            onChanged: (_) => _testPattern(),
          ),
          const SizedBox(height: 16),
          if (_testResult != null) _buildTestResult(),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
      ],
    );
  }

  Widget _buildTestResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isMatch ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(color: _isMatch ? Colors.green.shade300 : Colors.red.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _testResult!,
        style: TextStyle(
          color: _isMatch ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}