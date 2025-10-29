// 声明库并拆分为多个 part，保持对外 API 不变
library ns_syntax;

import 'dart:io';
import 'dart:convert';
import 'package:jarvis/core/logger.dart';

import 'lang_spec.dart';

// part 列表（新增）
part 'ns_syntax_types.dart';
part 'ns_syntax_ts.dart';
part 'ns_syntax_ast.dart';
part 'ns_syntax_eval_string.dart';
part 'ns_syntax_eval_numeric.dart';
part 'ns_syntax_eval_array.dart';
part 'ns_file_io.dart'; // 新增：文件 I/O 抽象与默认实现
part 'ns_syntax_eval_regex.dart'; // 新增：正则表达式求值

// AST（Abstract Syntax Tree，抽象语法树）是源代码结构的树形表示。
// 示例 AST
// Program
// ├─ Let(name="a", type=int, expr=IntLit(5))
// ├─ If(cond=BinOp("<", Ident("a"), IntLit(5)),
// │   then=[
// │     Print(expr=BinOp("*", IntLit(100), BinOp("-", Ident("a"), IntLit(1))))
// │   ],
// │   else=[
// │     While(cond=BinOp("<", Ident("a"), IntLit(10)),
// │           body=[ Set(name="a", expr=BinOp("+", Ident("a"), IntLit(1))) ])
// │   ])
// └─ Print(expr=Ident("a"))
//
// 构建流程
// - 词法分析：把源文本切成 token （关键字、类型、标识符、操作符、字面量、空白/注释）。
// - 语法分析：根据关键字与块边界（ if/else/end 、 while/end ），构造语句/块节点，表达式用递归下降或运算符优先级解析为表达式子树。
// - 语义执行：遍历 AST，按节点类型更新 env 、写入 outputs / errors 。
class NsSyntax {
  final List<List<NSToken>> lineTokens = [];
  final List<_CtrlBlock> ctrlStack = [];
  final Map<String, dynamic> env = {};
  final List<String> outputs = [];
  final List<String> errors = [];
  final int maxLoopIterations = 10000000;
  // 新增：逐条输出回调（可选）
  void Function(String line)? onOutput;

  // 新增：统一输出入口，既写入列表也触发回调
  void _emitOutput(String line) {
    outputs.add(line);
    final cb = onOutput;
    if (cb != null) cb(line);
  }

  void clear() {
    lineTokens.clear();
    ctrlStack.clear();
    env.clear();
    outputs.clear();
    errors.clear();
  }

  // lex 是 lexical analysis （词法分析）的缩写，词法：将一行切成 token 并保存到 lineTokens[index]
  List<NSToken> lex({required String line, required int index}) {
    final toks = <NSToken>[];
    int i = 0;
    if (line.isEmpty) {
      _ensureLine(index, toks);
      return toks;
    }

    bool isBlank(int c) => c == 9 || c == 32;
    bool isCommentStart(int c) => c == 35; // '#'
    bool isDigit(int c) => c >= 48 && c <= 57;
    bool isIdentStart(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
    bool isIdentChar(int c) => isIdentStart(c) || isDigit(c);
    bool isQuote(int c) => c == 34; // 新增：双引号
    void skipBlanks() {
      final start = i;
      while (i < line.length && isBlank(line.codeUnitAt(i))) i++;
      if (i > start) {
        toks.add(NSToken(NSTokenKind.blank, line.substring(start, i)));
      }
    }

    while (i < line.length) {
      skipBlanks();
      if (i >= line.length) break;
      final c = line.codeUnitAt(i);

      if (isCommentStart(c)) {
        toks.add(NSToken(NSTokenKind.comment, line.substring(i)));
        break;
      }

      // 新增：字符串字面量解析
      if (isQuote(c)) {
        i++; // 跳过开引号
        final buf = StringBuffer();
        while (i < line.length) {
          final cc = line.codeUnitAt(i);
          if (cc == 34) { i++; break; } // 结束引号
          if (cc == 92 && i + 1 < line.length) { // 反斜杠转义
            final esc = line[i + 1];
            switch (esc) {
              case 'n': buf.write('\n'); break;
              case 't': buf.write('\t'); break;
              case 'r': buf.write('\r'); break;
              case '"': buf.write('"'); break;
              case '\\': buf.write('\\'); break;
              default: buf.write(esc); break;
            }
            i += 2; continue;
          }
          buf.write(String.fromCharCode(cc));
          i++;
        }
        toks.add(NSToken(NSTokenKind.stringLit, buf.toString()));
        continue;
      }

      if (isDigit(c)) {
        final s = i;
        i++;
        while (i < line.length && isDigit(line.codeUnitAt(i))) i++;
        final word = line.substring(s, i);
        toks.add(NSToken(NSTokenKind.intLit, int.parse(word)));
        continue;
      }

      if (isIdentStart(c)) {
        final s = i;
        i++;
        while (i < line.length && isIdentChar(line.codeUnitAt(i))) i++;
        final word = line.substring(s, i);
        final lower = word.toLowerCase();

        final kwIdx = nsKeywords.indexOf(lower);
        if (kwIdx != -1) {
          toks.add(NSToken(NSTokenKind.keyword, kwIdx));
          continue;
        }
        final typeIdx = nsTypes.indexOf(lower);
        if (typeIdx != -1) {
          toks.add(NSToken(NSTokenKind.type, typeIdx));
          continue;
        }
        if (lower == 'true' || lower == 'false') {
          toks.add(NSToken(NSTokenKind.boolLit, lower == 'true'));
          continue;
        }
        toks.add(NSToken(NSTokenKind.ident, word));
        continue;
      }

      // 操作符：尝试最长匹配（>= <= == != && ||），否则单字符
      String? op;
      if (i + 1 < line.length) {
        final two = line.substring(i, i + 2);
        if (two == '>=' || two == '<=' || two == '==' || two == '!=' || two == '&&' || two == '||' || two == '->') {
          op = two; i += 2;
        }
      }
      if (op == null) {
        final ch = String.fromCharCode(c);
        const singles = ['+', '-', '*', '/', '%', '(', ')', '=', '>', '<', '!'];
        if (singles.contains(ch)) { op = ch; i++; }
      }
      if (op != null) {
        final idx = nsOperators.indexOf(op);
        toks.add(NSToken(NSTokenKind.operator, idx));
        continue;
      }

      // 其他不可识别字符直接作为标识符
      toks.add(NSToken(NSTokenKind.ident, String.fromCharCode(c)));
      i++;
    }

    _ensureLine(index, toks);
    return toks;
  }

  void _ensureLine(int index, List<NSToken> tokens) {
    while (lineTokens.length <= index) { lineTokens.add(<NSToken>[]); }
    lineTokens[index] = tokens;
  }

  // 语法校验：括号配对、控制块结构
  List<SyntaxIssue> validateSyntax() {
    final issues = <SyntaxIssue>[];
    final parenStack = <Position>[];
    ctrlStack.clear();

    for (var i = 0; i < lineTokens.length; i++) {
      final toks = lineTokens[i];
      if (toks.isEmpty) continue;

      for (var j = 0; j < toks.length; j++) {
        final t = toks[j];
        if (t.kind == NSTokenKind.operator) {
          final op = nsOperators[t.value as int];
          if (op == '(') {
            parenStack.add(Position(i, j));
          } else if (op == ')') {
            if (parenStack.isEmpty) {
              issues.add(SyntaxIssue(position: Position(i, j), reason: "多余的 ')'"));
            } else {
              parenStack.removeLast();
            }
          }
        }
      }

      // 行首关键字用于块结构校验
      NSToken? head;
      for (final t in toks) {
        if (t.kind == NSTokenKind.blank || t.kind == NSTokenKind.comment) continue;
        head = t; break;
      }
      if (head == null || head.kind != NSTokenKind.keyword) continue;
      final kw = nsKeywords[head.value as int];

      switch (kw) {
        case 'if':
          ctrlStack.add(_CtrlBlock('if', i));
          break;
        case 'else':
          if (ctrlStack.isEmpty || ctrlStack.last.kind != 'if') {
            issues.add(SyntaxIssue(position: Position(i, 0), reason: "'else' 没有匹配的 'if'"));
          } else if (ctrlStack.last.seenElse) {
            issues.add(SyntaxIssue(position: Position(i, 0), reason: "重复的 'else'（始于第 ${ctrlStack.last.startLine + 1} 行）"));
          } else {
            ctrlStack.last.seenElse = true;
          }
          break;
        case 'while':
          ctrlStack.add(_CtrlBlock('while', i));
          break;
        case 'end':
          if (ctrlStack.isEmpty) {
            issues.add(SyntaxIssue(position: Position(i, 0), reason: "'end' 没有匹配的块起始"));
          } else {
            ctrlStack.removeLast();
          }
          break;
        case 'break':
        case 'continue':
          final inWhile = ctrlStack.any((b) => b.kind == 'while');
          if (!inWhile) {
            issues.add(SyntaxIssue(position: Position(i, 0), reason: "'$kw' 不在 'while' 块内"));
          }
          break;
        default:
          break;
      }
    }

    for (final p in parenStack) {
      issues.add(SyntaxIssue(position: p, reason: "未闭合的 '('"));
    }
    for (final b in ctrlStack) {
      issues.add(SyntaxIssue(position: Position(b.startLine, 0), reason: "块 '${b.kind}' 未闭合（缺少 'end'）"));
    }

    return issues;
  }

  // 执行：真实运行脚本，收集输出与错误
  ExecResult execute() {
    outputs.clear();
    errors.clear();

    final issues = validateSyntax();
    if (issues.isNotEmpty) {
      for (final it in issues) {
        errors.add('Line ${it.position.line + 1}: ${it.reason}');
      }
      return ExecResult(
        success: false,
        outputs: List.unmodifiable(outputs),
        errors: List.unmodifiable(errors),
        envSnapshot: Map.unmodifiable(env),
      );
    }

    // 统一：解析整段为 AST，然后执行
    final ast = _parseRange(0, lineTokens.length - 1);
    _execNodes(ast);

    return ExecResult(
      success: errors.isEmpty,
      outputs: List.unmodifiable(outputs),
      errors: List.unmodifiable(errors),
      envSnapshot: Map.unmodifiable(env),
    );
  }

    // 第1阶段：异步执行（仅 await 文件命令阻塞）
  Future<ExecResult> executeAsync(NsFileIO io) async {
    outputs.clear();
    errors.clear();
    final issues = validateSyntax();
    if (issues.isNotEmpty) {
      for (final it in issues) {
        errors.add('Line ${it.position.line + 1}: ${it.reason}');
      }
      return ExecResult(
        success: false,
        outputs: List.unmodifiable(outputs),
        errors: List.unmodifiable(errors),
        envSnapshot: Map.unmodifiable(env),
      );
    }
    final ast = _parseRange(0, lineTokens.length - 1);
    final ok = await _execNodesAsync(ast, io);
    return ExecResult(
      success: ok && errors.isEmpty,
      outputs: List.unmodifiable(outputs),
      errors: List.unmodifiable(errors),
      envSnapshot: Map.unmodifiable(env),
    );
  }

  Future<bool> _execNodesAsync(List<_AstNode> nodes, NsFileIO io) async {
    for (final n in nodes) {
      if (n is _NodeFileCmd) {
        try {
          await _execFileAwait(n.toks, n.headIdx, io, n.lineNo);
        } catch (e) {
          errors.add('Line ${n.lineNo + 1}: $e');
          return false;
        }
        continue;
      }

      // 其它节点保持原同步语义
      if (n is _NodePrint) {
        try {
          final isStr = _isStringExpr(n.expr);
          if (isStr) {
            final out = _evalString(n.expr);
            _emitOutput('${n.lineNo + 1} │ $out');
          } else if (_isArrayExpr(n.expr)) {
            final arr = n.expr.first.kind == NSTokenKind.keyword
                ? _evalArray(n.expr)
                : (env[(n.expr.first.value as String)] as List<String>);
            _emitOutput('${n.lineNo + 1} │ ${_arrayToString(arr)}');
          } else {
            final isBool = _isBoolExpr(n.expr);
            final out = isBool
                ? (_evalBool(n.expr) ? 'true' : 'false')
                : _evalInt(n.expr).toString();
            _emitOutput('${n.lineNo + 1} │ $out');
          }
          // 新增：让出事件循环以刷新 UI
          await Future<void>.delayed(Duration.zero);
        } catch (e) {
          errors.add('Line ${n.lineNo + 1}: $e');
          return false;
        }
        continue;
      }

      if (n is _NodeLet) {
        if (!_execLet(n.toks, n.headIdx, n.lineNo)) return false;
        continue;
      }
      if (n is _NodeSet) {
        if (!_execSet(n.toks, n.headIdx, n.lineNo)) return false;
        continue;
      }
      if (n is _NodeExpr) {
        try { _evalAuto(n.expr); } catch (e) { errors.add('Line ${n.lineNo + 1}: $e'); return false; }
        continue;
      }
      if (n is _NodeIf) {
        final cond = _safeEvalBool(n.cond, n.lineNo, n.condStartCol);
        if (cond == null) continue;
        final ok = cond
            ? await _execNodesAsync(n.thenNodes, io)
            : (n.elseNodes != null ? await _execNodesAsync(n.elseNodes!, io) : true);
        if (!ok) return false;
        continue;
      }
      if (n is _NodeWhile) {
        int guard = 0;
        while (true) {
          final cond = _safeEvalBool(n.cond, n.lineNo, n.condStartCol);
          if (cond == null || !cond) break;
          final ok = await _execNodesAsync(n.bodyNodes, io);
          if (!ok) break;
          guard++;
          if (guard > maxLoopIterations) {
            errors.add('Line ${n.lineNo + 1}: while exceeded $maxLoopIterations iterations');
            break;
          }
        }
        continue;
      }
      if (n is _NodeBreak) continue;      // await 模式下，简单跳过（第1阶段不改循环控制）
      if (n is _NodeContinue) continue;
    }
    return true;
  }

  // 执行 await 文件命令（第1阶段）
  Future<void> _execFileAwait(List<NSToken> toks, int headIdx, NsFileIO io, int lineNo) async {
    // 结构：await <cmd> ...
    final rest = _stripBlanks(toks.sublist(headIdx + 1));
    if (rest.isEmpty || rest.first.kind != NSTokenKind.keyword) {
      throw 'await: expected file command';
    }
    final cmd = nsKeywords[rest.first.value as int];
    final args = _stripBlanks(rest.sublist(1));

    String readStringExpr(List<NSToken> t) {
      return _isStringExpr(t) ? _evalString(t) : _toStringVal(_evalAuto(t));
    }
    int readIntExpr(List<NSToken> t) => _evalInt(t);

    // 解析箭头 -> [type] <name>
    String? arrowName;
    String? arrowType; // 可选：string|bool|file
    int arrowIdx = args.indexWhere((x) => x.kind == NSTokenKind.operator && nsOperators[x.value as int] == '->');
    if (arrowIdx != -1) {
      final after = _stripBlanks(args.sublist(arrowIdx + 1));
      if (after.isEmpty) throw 'await: "->" missing target';
      if (after.first.kind == NSTokenKind.type) {
        arrowType = nsTypes[after.first.value as int];
        if (after.length < 2 || after[1].kind != NSTokenKind.ident) {
          throw 'await: "->" must be followed by <type> <name>';
        }
        arrowName = after[1].value as String;
      } else if (after.first.kind == NSTokenKind.ident) {
        arrowName = after.first.value as String;
      } else {
        throw 'await: invalid "->" target';
      }
    }

    switch (cmd) {
      case 'open': {
        // 形如：await open <string-expr|ident> mode <string-expr> -> file f
        final modeIdx = args.indexWhere((x) => x.kind == NSTokenKind.keyword && nsKeywords[x.value as int] == 'mode');
        if (modeIdx == -1) throw 'open: missing "mode"';
        final path = readStringExpr(_stripBlanks(args.sublist(0, modeIdx)));
        final modeToks = _stripBlanks(args.sublist(modeIdx + 1, arrowIdx == -1 ? args.length : arrowIdx));
        if (modeToks.isEmpty) throw 'open: empty mode';
        final mode = readStringExpr(modeToks).toLowerCase();
        if (arrowName == null || (arrowType != null && arrowType != 'file')) {
          throw 'open: "-> file <name>" required';
        }
        final h = await io.open(path, mode);
        env[arrowName] = h;
        return;
      }
      case 'close': {
        // await close <fileVar>
        if (args.isEmpty || args.first.kind != NSTokenKind.ident) throw 'close: expected file var';
        final name = args.first.value as String;
        final h = env[name];
        if (h is! NsFileHandle) throw 'close: "$name" is not file handle';
        await io.close(h);
        return;
      }
      case 'read': {
        // await read <fileVar> bytes <int-expr> -> string s
        if (args.isEmpty || args.first.kind != NSTokenKind.ident) throw 'read: expected file var';
        final name = args.first.value as String;
        final h = env[name];
        if (h is! NsFileHandle) throw 'read: "$name" is not file handle';
        final bytesIdx = args.indexWhere((x) => x.kind == NSTokenKind.keyword && nsKeywords[x.value as int] == 'bytes');
        if (bytesIdx != -1) {
          final n = readIntExpr(_stripBlanks(args.sublist(bytesIdx + 1, arrowIdx == -1 ? args.length : arrowIdx)));
          final data = await io.read(h, n);
          if (arrowName == null || (arrowType != null && arrowType != 'string')) throw 'read: "-> string <name>" required';
          env[arrowName] = data;
          return;
        }
        final lineIdx = args.indexWhere((x) => x.kind == NSTokenKind.keyword && nsKeywords[x.value as int] == 'line');
        if (lineIdx != -1) {
          final data = await io.readLine(h);
          if (arrowName == null || (arrowType != null && arrowType != 'string')) throw 'read: "-> string <name>" required';
          env[arrowName] = data;
          return;
        }

        throw 'read: expected "bytes" or "line"';
      }
      case 'write': {
        // await write <fileVar> <string-expr>
        if (args.isEmpty || args.first.kind != NSTokenKind.ident) throw 'write: expected file var';
        final name = args.first.value as String;
        final h = env[name];
        if (h is! NsFileHandle) throw 'write: "$name" is not file handle';
        final payload = readStringExpr(_stripBlanks(args.sublist(1, arrowIdx == -1 ? args.length : arrowIdx)));
        await io.write(h, payload);
        return;
      }
      case 'seek': {
        // await seek <fileVar> to <int-expr>
        if (args.isEmpty || args.first.kind != NSTokenKind.ident) throw 'seek: expected file var';
        final name = args.first.value as String;
        final h = env[name];
        if (h is! NsFileHandle) throw 'seek: "$name" is not file handle';
        final toIdx = args.indexWhere((x) => x.kind == NSTokenKind.keyword && nsKeywords[x.value as int] == 'to');
        if (toIdx == -1) throw 'seek: missing "to"';
        final pos = readIntExpr(_stripBlanks(args.sublist(toIdx + 1, arrowIdx == -1 ? args.length : arrowIdx)));
        await io.seek(h, pos);
        return;
      }
      case 'delete': {
        // await delete <string-expr|fileVar>
        if (args.isEmpty) throw 'delete: missing target';
        final target = args.first;
        String path;
        if (target.kind == NSTokenKind.ident && env[target.value as String] is NsFileHandle) {
          final h = env[target.value as String] as NsFileHandle;
          path = h.path;
        } else {
          path = readStringExpr(_stripBlanks(args.sublist(0, arrowIdx == -1 ? args.length : arrowIdx)));
        }
        await io.delete(path);
        return;
      }
      case 'create': {
        // await create <string-expr> -> file f
        final path = readStringExpr(_stripBlanks(args.sublist(0, arrowIdx == -1 ? args.length : arrowIdx)));
        if (arrowName == null || (arrowType != null && arrowType != 'file')) throw 'create: "-> file <name>" required';
        final h = await io.create(path);
        env[arrowName] = h;
        return;
      }
      case 'exists': {
        // await exists <string-expr|fileVar> -> bool ok
        String path;
        if (args.isNotEmpty && args.first.kind == NSTokenKind.ident && env[args.first.value as String] is NsFileHandle) {
          final h = env[args.first.value as String] as NsFileHandle;
          path = h.path;
        } else {
          path = readStringExpr(_stripBlanks(args.sublist(0, arrowIdx == -1 ? args.length : arrowIdx)));
        }
        final ok = await io.exists(path);
        if (arrowName == null || (arrowType != null && arrowType != 'bool')) throw 'exists: "-> bool <name>" required';
        env[arrowName] = ok;
        return;
      }
      case 'eof': {
        // await eof <fileVar> -> bool ok
        if (args.isEmpty || args.first.kind != NSTokenKind.ident) throw 'eof: expected file var';
        final name = args.first.value as String;
        final h = env[name];
        if (h is! NsFileHandle) throw 'eof: "$name" is not file handle';
        final ok = await io.eof(h);
        if (arrowName == null || (arrowType != null && arrowType != 'bool')) throw 'eof: "-> bool <name>" required';
        env[arrowName] = ok;
        return;
      }
      default:
        throw 'await: unknown file command "$cmd"';
    }
  }

    // 解析指定范围为 AST 列表（统一处理嵌套块）
  List<_AstNode> _parseRange(int start, int endInclusive) {
    final nodes = <_AstNode>[];
    int j = start;
    while (j <= endInclusive) {
      final toks = lineTokens[j];
      if (toks.isEmpty) { j++; continue; }
      final headIdx = _firstNonBlankIndex(toks);
      if (headIdx == -1) { j++; continue; }
      final head = toks[headIdx];

      if (head.kind == NSTokenKind.keyword) {
        final kw = nsKeywords[head.value as int];

        switch (kw) {
          case 'print':
            nodes.add(_NodePrint(j, _stripBlanks(toks.sublist(headIdx + 1))));
            j++;
            continue;

          case 'let':
            nodes.add(_NodeLet(j, toks, headIdx));
            j++;
            continue;

          case 'set':
            nodes.add(_NodeSet(j, toks, headIdx));
            j++;
            continue;

          case 'if': {
            final endIdx = _findBlockEnd(j + 1);
            if (endIdx == -1) { errors.add('Line ${j + 1}: missing "end" for if'); return nodes; }
            final elseIdx = _findElse(j + 1, endIdx);
            final cond = toks.sublist(headIdx + 1);
            // 关键修正：then 分支不包含 else 行
            final thenEnd = elseIdx == -1 ? endIdx : (elseIdx - 1);
            final thenNodes = _parseRange(j + 1, thenEnd);
            final elseNodes = elseIdx == -1 ? null : _parseRange(elseIdx + 1, endIdx);
            nodes.add(_NodeIf(j, headIdx + 1, cond, thenNodes, elseNodes));
            j = endIdx + 1;
            continue;
          }

          case 'while': {
            final endIdx = _findBlockEnd(j + 1);
            if (endIdx == -1) { errors.add('Line ${j + 1}: missing "end" for while'); return nodes; }
            final cond = toks.sublist(headIdx + 1);
            final bodyNodes = _parseRange(j + 1, endIdx);
            nodes.add(_NodeWhile(j, headIdx + 1, cond, bodyNodes));
            j = endIdx + 1;
            continue;
          }

          case 'break':
            nodes.add(_NodeBreak(j)); j++; continue;

          case 'continue':
            nodes.add(_NodeContinue(j)); j++; continue;

          case 'end':
            // 交由上层 parseRange 控制，遇到 end 直接到此停止
            j++; continue;
          case 'await':
            // 将整行作为文件命令，留给异步执行器解析
            nodes.add(_NodeFileCmd(j, toks, headIdx));
            j++;
            continue;
          default:
            errors.add('Line ${j + 1}: unknown keyword "$kw"');
            j++; continue;
        }
      } else {
        // 裸表达式（仅用于触发错误）
        nodes.add(_NodeExpr(j, _stripBlanks(toks)));
        j++;
      }
    }
    return nodes;
  }

  // 执行 AST 节点列表。返回循环控制标志以支持 break/continue 嵌套传播
  _LoopCtrl _execNodes(List<_AstNode> nodes) {
    for (final n in nodes) {
      if (n is _NodePrint) {
        try {
          final isStr = _isStringExpr(n.expr);
          if (isStr) {
            final out = _evalString(n.expr);
            outputs.add('${n.lineNo + 1} │ $out');
          } else if (_isArrayExpr(n.expr)) { // 新增：打印数组或 split 表达式
            final arr = n.expr.first.kind == NSTokenKind.keyword
                ? _evalArray(n.expr)
                : (env[(n.expr.first.value as String)] as List<String>);
            _emitOutput('${n.lineNo + 1} │ ${_arrayToString(arr)}');
          } else {
            final isBool = _isBoolExpr(n.expr);
            final out = isBool
                ? (_evalBool(n.expr) ? 'true' : 'false')
                : _evalInt(n.expr).toString();
            _emitOutput('${n.lineNo + 1} │ $out');
          }
        } catch (e) {
          errors.add('Line ${n.lineNo + 1}: $e');
          return _LoopCtrl.abort;
        }
        continue;
      }

      if (n is _NodeLet) {
        if (!_execLet(n.toks, n.headIdx, n.lineNo)) return _LoopCtrl.abort;
        continue;
      }

      if (n is _NodeSet) {
        if (!_execSet(n.toks, n.headIdx, n.lineNo)) return _LoopCtrl.abort;
        continue;
      }

      if (n is _NodeExpr) {
        try { _evalAuto(n.expr); } catch (e) { errors.add('Line ${n.lineNo + 1}: $e'); return _LoopCtrl.abort; }
        continue;
      }

      if (n is _NodeIf) {
        final cond = _safeEvalBool(n.cond, n.lineNo, n.condStartCol);
        if (cond == null) continue;
        final ctrl = cond ? _execNodes(n.thenNodes)
                          : (n.elseNodes != null ? _execNodes(n.elseNodes!) : _LoopCtrl.none);
        if (ctrl == _LoopCtrl.abort) return _LoopCtrl.abort;
        if (ctrl == _LoopCtrl.breakLoop) return _LoopCtrl.breakLoop;
        if (ctrl == _LoopCtrl.continueLoop) return _LoopCtrl.continueLoop;
        continue;
      }

      if (n is _NodeWhile) {
        
        int guard = 0;
        while (true) {
          final cond = _safeEvalBool(n.cond, n.lineNo, n.condStartCol);
          if (cond == null) break;
          if (!cond) break;
          final ctrl = _execNodes(n.bodyNodes);
          if (ctrl == _LoopCtrl.breakLoop) break;
          if (ctrl == _LoopCtrl.abort) break;
          guard++;
          if (guard > maxLoopIterations) {
            errors.add('Line ${n.lineNo + 1}: while exceeded $maxLoopIterations iterations');
            break;
          }
        }
        continue;
      }

      if (n is _NodeBreak)      return _LoopCtrl.breakLoop;
      if (n is _NodeContinue)   return _LoopCtrl.continueLoop;
    }
    return _LoopCtrl.none;
  }

  // ===== 语句实现：let/set =====
  bool _execLet(List<NSToken> toks, int headIdx, int lineNo) {
    final head = _stripBlanks(toks.sublist(headIdx + 1));
    if (head.length < 4) { errors.add('Line ${lineNo + 1}: Syntax: let int|bool|string|array|regex <name> = <expr>'); return false; }
    final tyTok = head[0];
    final nameTok = head[1];
    final eqTok = head[2];
    if (tyTok.kind != NSTokenKind.type || nameTok.kind != NSTokenKind.ident || !(eqTok.kind == NSTokenKind.operator && nsOperators[eqTok.value as int] == '=')) {
      errors.add('Line ${lineNo + 1}: Syntax: let int|bool|string|array|regex <name> = <expr>'); return false;
    }
    final name = nameTok.value as String;
    final expr = _stripBlanks(head.sublist(3));
    try {
      if (tyTok.text == 'int')       { env[name] = _evalInt(expr); }
      else if (tyTok.text == 'bool') { env[name] = _evalBool(expr); }
      else if (tyTok.text == 'string') { env[name] = _evalString(expr); }
      else if (tyTok.text == 'array')  { env[name] = _evalArray(expr); }
      else if (tyTok.text == 'regex')  { env[name] = _evalRegex(expr); }
      else { errors.add('Line ${lineNo + 1}: Unknown type: ${tyTok.text}'); return false; }
    } catch (e) {
      errors.add('Line ${lineNo + 1}: $e'); return false;
    }
    return true;
  }

  bool _execSet(List<NSToken> toks, int headIdx, int lineNo) {
    final head = _stripBlanks(toks.sublist(headIdx + 1));
    if (head.length < 3) { errors.add('Line ${lineNo + 1}: Syntax: set <name> = <expr>'); return false; }
    final nameTok = head[0];
    final eqTok = head[1];
    if (nameTok.kind != NSTokenKind.ident || !(eqTok.kind == NSTokenKind.operator && nsOperators[eqTok.value as int] == '=')) {
      errors.add('Line ${lineNo + 1}: Syntax: set <name> = <expr>'); return false;
    }
    final name = nameTok.value as String;
    if (!env.containsKey(name)) { errors.add('Line ${lineNo + 1}: Unknown variable: $name'); return false; }
    final expr = _stripBlanks(head.sublist(2));
    final cur = env[name];
    try {
      if (cur is int)           { env[name] = _evalInt(expr); }
      else if (cur is bool)     { env[name] = _evalBool(expr); }
      else if (cur is String)   { env[name] = _evalString(expr); }
      else if (cur is List<String>) { env[name] = _evalArray(expr); } // 新增：更新数组
      else if (cur is RegExp)   { env[name] = _evalRegex(expr); } // 新增：更新 regex
      else { errors.add('Line ${lineNo + 1}: Unsupported var type for set: $name'); return false; }
    } catch (e) {
      errors.add('Line ${lineNo + 1}: $e'); return false;
    }
    return true;
  }

  // ===== 辅助：查找 else/end =====
  int _findElse(int from, int endInclusive) {
    // 仅匹配当前 if 的顶层 else，忽略嵌套块中的 else
    int nest = 0;
    for (var j = from; j <= endInclusive; j++) {
      final toks = lineTokens[j];
      final idx = _firstNonBlankIndex(toks);
      if (idx == -1) continue;
      final h = toks[idx];
      if (h.kind == NSTokenKind.keyword) {
        final kw = nsKeywords[h.value as int];
        if (kw == 'if' || kw == 'while') {
          nest++;
        } else if (kw == 'end') {
          if (nest > 0) nest--;
        } else if (kw == 'else' && nest == 0) {
          return j;
        }
      }
    }
    return -1;
  }

  int _findBlockEnd(int from) {
    int nest = 1;
    for (var j = from; j < lineTokens.length; j++) {
      final toks = lineTokens[j];
      final idx = _firstNonBlankIndex(toks);
      if (idx == -1) continue;
      final h = toks[idx];
      if (h.kind == NSTokenKind.keyword) {
        final kw = nsKeywords[h.value as int];
        if (kw == 'if' || kw == 'while') nest++;
        else if (kw == 'end') {
          nest--;
          if (nest == 0) return j;
        }
      }
    }
    return -1;
  }

  // 找到行内的第一个非空白和注释token
  int _firstNonBlankIndex(List<NSToken> toks) {
    for (int i = 0; i < toks.length; i++) {
      final t = toks[i];
      if (t.kind != NSTokenKind.blank && t.kind != NSTokenKind.comment) return i;
    }
    return -1;
  }

  // 去掉行内的空白和注释token
  List<NSToken> _stripBlanks(List<NSToken> t) =>
      t.where((x) => x.kind != NSTokenKind.blank && x.kind != NSTokenKind.comment).toList();

  // 新增：判定是否为字符串表达式
  bool _isStringExpr(List<NSToken> t) {
    for (final x in t) {
      if (x.kind == NSTokenKind.stringLit) return true;
      if (x.kind == NSTokenKind.ident) {
        final name = x.value as String;
        final v = env[name];
        if (v is String) return true;
      }
    }
    return false;
  }

  // 新增：字符串表达式求值（支持 + 拼接，string + int/bool 自动转 string）
  String _evalString(List<NSToken> t) {
    final ts = _TS(_stripBlanks(t));
    final v = _strExpr(ts);
    if (!ts.end) throw "string expr: unexpected '${_tokStr(ts.peek())}'";
    return v;
  }

  String _strExpr(_TS ts) {
    var s = _strFactor(ts);
    while (!ts.end) {
      final saved = ts.save();
      if (ts.matchOp('+')) {
        s = s + _strFactor(ts);
      } else {
        ts.restore(saved);
        break;
      }
    }
    return s;
  }

  String _strFactor(_TS ts) {
    if (ts.end) throw 'string expr: unexpected end';
    final t = ts.peek();

    // 直接字符串字面量
    if (t.kind == NSTokenKind.stringLit) {
      ts.next();
      return t.value as String;
    }

    // 括号：( ... ) 子表达式
    if (t.kind == NSTokenKind.operator && nsOperators[t.value as int] == '(') {
      final start = ts.pos;
      int depth = 0;
      int i = start;
      while (i < ts.t.length) {
        final tok = ts.t[i];
        if (tok.kind == NSTokenKind.operator) {
          final op = nsOperators[tok.value as int];
          if (op == '(') {
            depth++;
          } else if (op == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        i++;
      }
      if (i >= ts.t.length || (ts.t[i].kind != NSTokenKind.operator) || nsOperators[ts.t[i].value as int] != ')') {
        throw "string expr: missing ')'";
      }
      final inside = _stripBlanks(ts.t.sublist(start + 1, i));
      final val = _isStringExpr(inside) ? _evalString(inside) : _toStringVal(_evalAuto(inside));
      ts.pos = i + 1;
      return val;
    }

    // 标识符：变量（string 直接用，int/bool/array 转字符串）
    if (t.kind == NSTokenKind.ident) {
      final name = t.value as String;
      ts.next();
      final v = env[name];
      if (v is String) return v;
      if (v is int || v is bool) return _toStringVal(v);
      if (v is List<String>) return '[${v.join(', ')}]'; // 支持数组参与拼接
      throw "string expr: unknown variable '$name'";
    }

    // 其它：直到顶层 +
    final startPos = ts.pos;
    int depth = 0;
    int i = startPos;
    while (i < ts.t.length) {
      final tok = ts.t[i];
      if (tok.kind == NSTokenKind.operator) {
        final op = nsOperators[tok.value as int];
        if (op == '(') {
          depth++;
        } else if (op == ')') {
          if (depth == 0) break;
          depth--;
        } else if (op == '+' && depth == 0) {
          break;
        }
      }
      i++;
    }
    final sub = _stripBlanks(ts.t.sublist(startPos, i));
    ts.pos = i;
    final val = _evalAuto(sub);
    return _toStringVal(val);
  }

  // 新增：统一把 int/bool 转为字符串
  String _toStringVal(dynamic v) {
    if (v is String) return v;
    if (v is int) return v.toString();
    if (v is bool) return v ? 'true' : 'false';
    if (v is List<String>) return '[${v.join(', ')}]';
    throw 'string expr: unsupported value';
  }

  // ===== 表达式求值（int / bool + 括号优先）=====
  bool _isBoolExpr(List<NSToken> t) {
    for (final x in t) {
      if (x.kind == NSTokenKind.boolLit) return true;
      if (x.kind == NSTokenKind.operator) {
        final op = nsOperators[x.value as int];
        if (op == '||' || op == '&&' || op == '!' ||
            op == '==' || op == '!=' || op == '>' || op == '<' || op == '>=' || op == '<=') {
          return true;
        }
      }
    }
    // 单标识符：根据变量类型判定
    if (t.length == 1 && t[0].kind == NSTokenKind.ident) {
      final name = t[0].value as String;
      final v = env[name];
      if (v is bool) return true;
    }
    return false;
  }

  dynamic _evalAuto(List<NSToken> t) => _isBoolExpr(t) ? _evalBool(t) : _evalInt(t);

  bool _evalBool(List<NSToken> t) {
    final ts = _TS(t);
    final v = _boolOr(ts);
    if (!ts.end) throw "bool expr: unexpected '${_tokStr(ts.peek())}'";
    return v;
  }
  bool _boolOr(_TS ts) {
    var v = _boolAnd(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('||')) {
        v = v || _boolAnd(ts);
      } else {
        ts.restore(s); break;
      }
    }
    return v;
  }
  bool _boolAnd(_TS ts) {
    var v = _boolNot(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('&&')) {
        v = v && _boolNot(ts);
      } else {
        ts.restore(s); break;
      }
    }
    return v;
  }
  bool _boolNot(_TS ts) {
    if (ts.matchOp('!')) return !_boolNot(ts);
    return _boolPrimary(ts);
  }
  bool _boolPrimary(_TS ts) {
    if (ts.end) throw 'bool expr: unexpected end';
    final t = ts.peek();

    if (t.kind == NSTokenKind.boolLit) { ts.next(); return (t.value as bool); }

    // 处理布尔变量标识符作为布尔基本项
    if (t.kind == NSTokenKind.ident) {
      final name = t.value as String;
      final v = env[name];
      if (v is bool) { ts.next(); return v; }
    }

    if (t.kind == NSTokenKind.operator && nsOperators[t.value as int] == '(') {
      final start = ts.pos;
      int depth = 0;
      int i = start;
      while (i < ts.t.length) {
        final tok = ts.t[i];
        if (tok.kind == NSTokenKind.operator) {
          final op = nsOperators[tok.value as int];
          if (op == '(') { depth++; }
          else if (op == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        i++;
      }
      final inside = (i > start)
          ? _stripBlanks(ts.t.sublist(start + 1, i))
          : <NSToken>[];
      final isBoolInside = _isBoolExpr(inside);
      if (isBoolInside) {
        ts.next();
        final v = _boolOr(ts);
        if (!ts.matchOp(')')) throw "bool expr: missing ')'";
        return v;
      }
      // 括号不是布尔表达式，则继续比较分支
    }

    // 比较：intExpr <cmp> intExpr
    final left = _intExpr(ts);
    if (ts.end) throw "bool expr: missing comparator";
    final cmp = ts.next();
    if (cmp.kind != NSTokenKind.operator) throw "bool expr: expected comparator";
    final op = nsOperators[cmp.value as int];
    final right = _intExpr(ts);

    switch (op) {
      case '==': return left == right;
      case '!=': return left != right;
      case '>':  return left > right;
      case '<':  return left < right;
      case '>=': return left >= right;
      case '<=': return left <= right;
      default: throw "bool expr: unknown comparator '$op'";
    }
  }

  int _evalInt(List<NSToken> t) {
    final ts = _TS(t);
    final v = _intExpr(ts);
    if (!ts.end) throw "int expr: unexpected '${_tokStr(ts.peek())}'";
    return v;
  }
  int _intExpr(_TS ts) {
    var v = _intTerm(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('+')) {
        v = v + _intTerm(ts);
      } else if (ts.matchOp('-')) {
        v = v - _intTerm(ts);
      } else {
        ts.restore(s); break;
      }
    }
    return v;
  }
  int _intTerm(_TS ts) {
    var v = _intFactor(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('*')) {
        v = v * _intFactor(ts);
      } else if (ts.matchOp('/')) {
        final r = _intFactor(ts);
        if (r == 0) throw 'division by zero';
        v = v ~/ r;
      } else if (ts.matchOp('%')) {
        final r = _intFactor(ts);
        if (r == 0) throw 'mod by zero';
        v = v % r;
      } else {
        ts.restore(s); break;
      }
    }
    return v;
  }
  int _intFactor(_TS ts) {
    if (ts.matchOp('-')) return -_intFactor(ts);
    if (ts.end) throw 'int expr: unexpected end';
    final t = ts.peek();
    
    // 新增：len <arrayVar>，返回数组长度
    if (t.kind == NSTokenKind.keyword && nsKeywords[t.value as int] == 'len') {
      ts.next(); // 消费 'len'
      if (ts.end) throw 'len: expected array identifier';
      final id = ts.peek();
      if (id.kind != NSTokenKind.ident) throw 'len: expected array identifier';
      final name = id.value as String;
      ts.next(); // 消费标识符
      final v = env[name];
      if (v is List<String>) return v.length;
      throw 'len: "$name" is not an array';
    }
    if (t.kind == NSTokenKind.intLit) { ts.next(); return (t.value as int); }

    if (t.kind == NSTokenKind.operator && nsOperators[t.value as int] == '(') {
      ts.next();
      final v = _intExpr(ts);
      if (!ts.matchOp(')')) throw "int expr: missing ')'";
      return v;
    }

    // 标识符：变量
    if (t.kind == NSTokenKind.ident) {
      final name = t.value as String; ts.next();
      final v = env[name];
      if (v is int) return v;
      throw "int expr: unknown variable '$name'";
    }

    throw "int expr: unexpected token '${_tokStr(ts.next())}'";
  }

  bool? _safeEvalBool(List<NSToken> t, int line, int colStart) {
    try { return _evalBool(_stripBlanks(t)); } catch (e) { errors.add('Line ${line + 1}: $e'); return null; }
  }

  String _tokStr(NSToken t) => t.text;
}

enum _LoopCtrl { none, breakLoop, continueLoop, abort }