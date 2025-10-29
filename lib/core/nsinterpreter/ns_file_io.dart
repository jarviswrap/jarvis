part of ns_syntax;

// 文件句柄：包含路径与（可选）打开的随机访问文件
class NsFileHandle {
  final String path;
  RandomAccessFile? raf;
  String mode;
  NsFileHandle({required this.path, this.raf, required this.mode});
}

abstract class NsFileIO {
  Future<NsFileHandle> open(String path, String mode);   // mode: r | rw | a
  Future<void> close(NsFileHandle h);
  Future<String> read(NsFileHandle h, int n);            // 读取 n 字节（UTF-8）
  Future<void> write(NsFileHandle h, String data);       // 写入（UTF-8）
  Future<void> seek(NsFileHandle h, int pos);
  Future<void> delete(String path);
  Future<NsFileHandle> create(String path);              // 创建并返回可写句柄
  Future<bool> exists(String path);
  // 新增：判断是否到达文件末尾
   Future<bool> eof(NsFileHandle h);
  // 新增：按行读取，返回不包含换行符的字符串；EOF 返回空字符串
  Future<String> readLine(NsFileHandle h);
}

class DefaultFileIO implements NsFileIO {
  @override
  Future<NsFileHandle> open(String path, String mode) async {
    final file = File(path);
    RandomAccessFile raf;
    switch (mode) {
      case 'r':
        raf = await file.open();
        await raf.setPosition(0);
        break;
      case 'rw':
        if (!await file.exists()) { await file.create(recursive: true); }
        raf = await file.open(mode: FileMode.append);
        await raf.setPosition(0);
        break;
      case 'a':
        if (!await file.exists()) { await file.create(recursive: true); }
        raf = await file.open(mode: FileMode.append);
        break;
      default:
        throw 'open: unknown mode "$mode"';
    }
    return NsFileHandle(path: path, raf: raf, mode: mode);
  }

  @override
  Future<void> close(NsFileHandle h) async {
    if (h.raf != null) {
      try { await h.raf!.close(); } finally { h.raf = null; }
    }
  }

  @override
  Future<String> read(NsFileHandle h, int n) async {
    if (h.raf == null) throw 'read: file is not opened';
    final bytes = await h.raf!.read(n);
    return utf8.decode(bytes);
  }

  @override
  Future<void> write(NsFileHandle h, String data) async {
    if (h.raf == null) throw 'write: file is not opened';
    final bytes = utf8.encode(data);
    await h.raf!.writeFrom(bytes);
  }

  @override
  Future<void> seek(NsFileHandle h, int pos) async {
    if (h.raf == null) throw 'seek: file is not opened';
    await h.raf!.setPosition(pos);
  }

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  @override
  Future<NsFileHandle> create(String path) async {
    final f = File(path);
    if (!await f.exists()) {
      await f.create(recursive: true);
    }
    final raf = await f.open(mode: FileMode.append);
    await raf.setPosition(0);
    return NsFileHandle(path: path, raf: raf, mode: 'rw');
  }

  @override
  Future<bool> exists(String path) async {
    return await File(path).exists();
  }

  // 新增实现：判断 EOF（当前位置 >= 文件长度）
  @override
  Future<bool> eof(NsFileHandle h) async {
    if (h.raf == null) throw 'eof: file is not opened';
    final pos = await h.raf!.position();
    final len = await h.raf!.length();
    return pos >= len;
  }

  // 新增实现：按行读取（不包含换行符；支持 CRLF/ LF）
  @override
  Future<String> readLine(NsFileHandle h) async {
    if (h.raf == null) throw 'readLine: file is not opened';
    final buf = <int>[];
    while (true) {
      final chunk = await h.raf!.read(1);
      if (chunk.isEmpty) {
        // EOF
        break;
      }
      final b = chunk[0];
      if (b == 0x0A) {
        // LF：行结束
        break;
      }
      if (b == 0x0D) {
        // CR：可能是 CRLF，下一字节若是 LF 会在下轮消费
        continue;
      }
      buf.add(b);
    }
    return utf8.decode(buf);
  }
}