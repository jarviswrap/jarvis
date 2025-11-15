part of ns_syntax;

abstract class _AstNode {
  final int lineNo;
  const _AstNode(this.lineNo);
}

class _NodePrint extends _AstNode {
  final List<NSToken> expr;
  const _NodePrint(super.lineNo, this.expr);
}

class _NodeLet extends _AstNode {
  final List<NSToken> toks;
  final int headIdx;
  const _NodeLet(super.lineNo, this.toks, this.headIdx);
}

class _NodeSet extends _AstNode {
  final List<NSToken> toks;
  final int headIdx;
  const _NodeSet(super.lineNo, this.toks, this.headIdx);
}

class _NodeFileCmd extends _AstNode {
  final List<NSToken> toks;
  final int headIdx;   // 索引位于 'await'
  const _NodeFileCmd(super.lineNo, this.toks, this.headIdx);
}

class _NodeExpr extends _AstNode {
  final List<NSToken> expr;
  const _NodeExpr(super.lineNo, this.expr);
}

class _NodeIf extends _AstNode {
  final int condStartCol;
  final List<NSToken> cond;
  final List<_AstNode> thenNodes; // 条件为 true 时需要执行的那一段代码块，在这里称为 then 分支
  final List<_AstNode>? elseNodes;
  const _NodeIf(super.lineNo, this.condStartCol, this.cond, this.thenNodes, this.elseNodes);
}

class _NodeWhile extends _AstNode {
  final int condStartCol;
  final List<NSToken> cond;
  final List<_AstNode> bodyNodes;
  const _NodeWhile(super.lineNo, this.condStartCol, this.cond, this.bodyNodes);
}

class _NodeBreak extends _AstNode {
  const _NodeBreak(super.lineNo);
}

class _NodeContinue extends _AstNode {
  const _NodeContinue(super.lineNo);
}