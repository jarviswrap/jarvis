import 'dart:io';

class SdkApi {
  final String package;
  final String className;
  final String methodName;
  final String signature;

  const SdkApi({
    required this.package,
    required this.className,
    required this.methodName,
    required this.signature,
  });

  @override
  String toString() => '$package.$className#$methodName';

  @override
  bool operator ==(Object other) {
    return other is SdkApi &&
        other.package == package &&
        other.className == className &&
        other.methodName == methodName &&
        other.signature == signature;
  }

  @override
  int get hashCode => Object.hash(package, className, methodName, signature);
}

class SdkApiCollectResult {
  final List<SdkApi> apis;
  final List<String> errors;
  const SdkApiCollectResult({required this.apis, required this.errors});
}

class CallSite {
  final String filePath;
  final int line;
  final String lineText;
  final String kind; // 'instance' or 'static'

  const CallSite({
    required this.filePath,
    required this.line,
    required this.lineText,
    required this.kind,
  });
}

class SdkAnalysisResult {
  final Map<SdkApi, List<CallSite>> usages;
  final List<String> errors;

  const SdkAnalysisResult({
    required this.usages,
    required this.errors,
  });

  int get apiCount => usages.length;
  int get callSiteCount => usages.values.fold(0, (sum, list) => sum + list.length);
}

class AndroidSdkAnalyzer {
  // 第一步：提取 SDK 可被外部调用的接口（基于源码目录，支持 .java/.kt）
  Future<List<SdkApi>> extractSdkApis({
    required String sdkPath,
  }) async {
    final errors = <String>[];
    final apis = await _collectSdkApis(sdkPath, errors);
    // 目前不抛错，错误由页面以提示方式展示。这里直接返回接口集合。
    return apis;
  }

  Future<List<ProjectDependency>> discoverDependencies({
    required String projectPath,
  }) async {
    return const <ProjectDependency>[];
  }

  Future<List<ProjectDependency>> discoverDependenciesFromGradle({
    required String projectPath,
  }) async {
    final coords = <DependencyCoord>{};
    coords.addAll(await _collectCoordsFromGradleFiles(projectPath));
    coords.addAll(await _collectCoordsFromVersionCatalogs(projectPath));

    final deps = <ProjectDependency>[];
    final home = Platform.environment['HOME'] ?? '';
    final base = Directory('$home/.gradle/caches/modules-2/files-2.1');
    if (!base.existsSync()) return deps;

    for (final c in coords) {
      final groupDir = Directory('${base.path}/${c.group}/${c.name}/${c.version}');
      if (!groupDir.existsSync()) continue;

      final files = groupDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.aar') || f.path.endsWith('.jar'))
          .toList();

      File? picked;
      String kind = 'jar';
      final aars = files.where((f) => f.path.endsWith('.aar')).toList();
      if (aars.isNotEmpty) {
        picked = aars.first;
        kind = 'aar';
      } else {
        final jars = files.where((f) => f.path.endsWith('.jar')).toList();
        if (jars.isNotEmpty) {
          picked = jars.first;
          kind = 'jar';
        }
      }
      if (picked == null) continue;

      deps.add(ProjectDependency(
        module: c.name,
        group: c.group,
        version: c.version,
        artifactPath: picked.path,
        kind: kind,
      ));
    }

    // 去重与排序
    final seen = <String>{};
    deps.retainWhere((d) => seen.add('${d.group}:${d.module}:${d.version}:${d.artifactPath}'));
    deps.sort((a, b) {
      final g = a.group.compareTo(b.group);
      if (g != 0) return g;
      final m = a.module.compareTo(b.module);
      if (m != 0) return m;
      return a.version.compareTo(b.version);
    });
    return deps;
  }

  Future<Set<DependencyCoord>> _collectCoordsFromGradleFiles(String projectPath) async {
    final set = <DependencyCoord>{};
    final gradleFiles = Directory(projectPath)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) {
          final name = f.path.split(RegExp(r'[\\/]')).last;
          return name == 'build.gradle' || name == 'build.gradle.kts';
        });

    final coordRegex = RegExp(r'''["']([\w\.\-]+):([\w\.\-]+):([\w\.\-]+)["']''');
    final mapStyle = RegExp(
        r'''group\s*:\s*["']([\w\.\-]+)["']\s*,\s*name\s*:\s*["']([\w\.\-]+)["']\s*,\s*version\s*:\s*["']([\w\.\-]+)["']''');

    for (final file in gradleFiles) {
      List<String> lines;
      try {
        lines = file.readAsLinesSync();
      } catch (_) {
        continue;
      }
      bool inDeps = false;
      for (final line in lines) {
        final t = line.trim();
        if (t.startsWith('dependencies')) {
          inDeps = true;
          continue;
        }
        if (inDeps && t.startsWith('}')) {
          inDeps = false;
          continue;
        }
        if (!inDeps) continue;

        final startsWithConfig = t.startsWith('implementation') ||
            t.startsWith('api') ||
            t.startsWith('compileOnly') ||
            t.startsWith('runtimeOnly');

        if (!startsWithConfig) continue;

        final m1 = coordRegex.firstMatch(t);
        if (m1 != null) {
          set.add(DependencyCoord(m1.group(1)!, m1.group(2)!, m1.group(3)!));
          continue;
        }
        final m2 = mapStyle.firstMatch(t);
        if (m2 != null) {
          set.add(DependencyCoord(m2.group(1)!, m2.group(2)!, m2.group(3)!));
        }
      }
    }
    return set;
  }

  // 解析版本目录：gradle/libs.versions.toml 中的 libraries 定义
  Future<Set<DependencyCoord>> _collectCoordsFromVersionCatalogs(String projectPath) async {
    final set = <DependencyCoord>{};
    final projectDir = Directory(projectPath);
    if (!projectDir.existsSync()) return set;

    // 默认路径
    final defaultToml = File('$projectPath/gradle/libs.versions.toml');
    final tomlFiles = <File>[
      if (defaultToml.existsSync()) defaultToml,
      ...projectDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.versions.toml')),
    ];

    for (final f in tomlFiles) {
      List<String> lines;
      try {
        lines = f.readAsLinesSync();
      } catch (_) {
        continue;
      }
      String currentSection = '';
      final versions = <String, String>{}; // key -> version string
      final libs = <String, Map<String, String>>{}; // libKey -> {group,name,version|version.ref}

      String trimQuotes(String s) => s.replaceAll(RegExp(r'''^["']|["']$'''), '');

      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final secMatch = RegExp(r'^\[(.+)\]$').firstMatch(line);
        if (secMatch != null) {
          currentSection = secMatch.group(1)!; // e.g., versions, libraries, bundles
          continue;
        }

        if (currentSection == 'versions') {
          final m = RegExp(r'''^([\w\.\-]+)\s*=\s*["\']([^"\']+)["\']''').firstMatch(line);
          if (m != null) {
            versions[m.group(1)!] = m.group(2)!;
          }
        } else if (currentSection == 'libraries') {
          // 长写：okhttp = { group = "com.squareup.okhttp3", name = "okhttp", version.ref = "okhttp" }
          final longForm = RegExp(
                  r'^([\w\.\-]+)\s*=\s*\{\s*([^}]+)\s*\}')
              .firstMatch(line);
          if (longForm != null) {
            final key = longForm.group(1)!;
            final body = longForm.group(2)!;
            final g = RegExp(r'''group\s*=\s*["\']([^"\']+)["\']''').firstMatch(body)?.group(1);
            final n = RegExp(r'''name\s*=\s*["\']([^"\']+)["\']''').firstMatch(body)?.group(1);
            final v = RegExp(r'''version\s*=\s*["\']([^"\']+)["\']''').firstMatch(body)?.group(1);
            final vr = RegExp(r'''version\.ref\s*=\s*["\']([^"\']+)["\']''').firstMatch(body)?.group(1);
            final map = <String, String>{};
            if (g != null) map['group'] = g;
            if (n != null) map['name'] = n;
            if (v != null) map['version'] = v;
            if (vr != null) map['version.ref'] = vr;
            libs[key] = map;
            continue;
          }
          // 短写：guava = "com.google.guava:guava:31.1-jre"
          final shortForm = RegExp(
                  r'''^([\w\.\-]+)\s*=\s*["\']([\w\.\-]+):([\w\.\-]+):([^"\']+)["\']''')
              .firstMatch(line);
          if (shortForm != null) {
            final key = shortForm.group(1)!;
            libs[key] = {
              'group': shortForm.group(2)!,
              'name': shortForm.group(3)!,
              'version': shortForm.group(4)!,
            };
          }
        }
      }

      // 汇总坐标：解析 version.ref -> versions
      for (final entry in libs.values) {
        final group = entry['group'];
        final name = entry['name'];
        String? version = entry['version'];
        final ref = entry['version.ref'];
        if (version == null && ref != null) {
          version = versions[ref];
        }
        if (group != null && name != null && version != null) {
          set.add(DependencyCoord(group, name, version));
        }
      }
    }
    return set;
  }

  // 直接从 .aar 或 classes.jar 提取接口（通过系统的 jar/javap 工具）
  Future<List<SdkApi>> extractSdkApisFromBinary({
    required String sdkBinaryPath, // .aar 或 .jar
  }) async {
    String? classesJarPath;
    if (sdkBinaryPath.endsWith('.aar')) {
      classesJarPath = await _extractClassesJarFromAar(sdkBinaryPath);
    } else if (sdkBinaryPath.endsWith('.jar')) {
      classesJarPath = sdkBinaryPath;
    }
    if (classesJarPath == null) {
      throw Exception('无法识别的 SDK 二进制：$sdkBinaryPath（仅支持 .aar 或 .jar）');
    }

    final result = await _collectSdkApisFromJar(classesJarPath);
    if (result.errors.isNotEmpty) {
      // 聚合错误并提示
      throw Exception(result.errors.join('\n'));
    }
    if (result.apis.isEmpty) {
      throw Exception('未在 ${classesJarPath} 提取到任何公开/受保护方法，请检查二进制内容是否包含可访问方法。');
    }
    return result.apis;
  }

  // 第二步：根据已提取的接口集合，在项目中确认具体调用点
  Future<SdkAnalysisResult> confirmUsages({
    required String projectPath,
    required List<SdkApi> sdkApis,
  }) async {
    final errors = <String>[];
    final usages = await _collectProjectUsagesByApis(
      projectPath: projectPath,
      sdkApis: sdkApis,
      errors: errors,
    );
    return SdkAnalysisResult(usages: usages, errors: errors);
  }

  Future<SdkAnalysisResult> analyze({
    required String projectPath,
    required String sdkPath,
    required String sdkPackagePrefix,
  }) async {
    final errors = <String>[];
    final sdkApis = await _collectSdkApis(sdkPath, errors);
    final usages = await _collectProjectUsages(
      projectPath: projectPath,
      sdkPackagePrefix: sdkPackagePrefix,
      sdkApis: sdkApis,
      errors: errors,
    );
    return SdkAnalysisResult(usages: usages, errors: errors);
  }

  // 使用已识别的 SDK 接口集合扫描项目，确认调用点
  Future<Map<SdkApi, List<CallSite>>> _collectProjectUsagesByApis({
    required String projectPath,
    required List<SdkApi> sdkApis,
    required List<String> errors,
  }) async {
    final usages = <SdkApi, List<CallSite>>{};
    final sdkApisByClass = <String, List<SdkApi>>{}; // FQN class -> apis
    final sdkClassSet = <String>{}; // FQN class set
    final simpleToFqn = <String, Set<String>>{}; // SimpleName -> {FQN}

    for (final api in sdkApis) {
      final fqnClass = '${api.package}.${api.className}';
      (sdkApisByClass[fqnClass] ??= []).add(api);
      sdkClassSet.add(fqnClass);
      (simpleToFqn[api.className] ??= <String>{}).add(fqnClass);
    }

    final dir = Directory(projectPath);
    if (!dir.existsSync()) {
      errors.add('项目路径不存在：$projectPath');
      return usages;
    }
    final files = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.java') || f.path.endsWith('.kt'));

    for (final f in files) {
      List<String> lines;
      try {
        lines = await f.readAsLines();
      } catch (e) {
        errors.add('读取项目文件失败：${f.path} · $e');
        continue;
      }

      // 收集 imports 映射：SimpleName -> FQN
      final importedSimpleToFqn = <String, String>{};
      for (final line in lines) {
        final m = RegExp(r'^\s*import\s+([\w\.]+)\s*;?').firstMatch(line);
        if (m != null) {
          final fqn = m.group(1)!;
          final simple = fqn.split('.').last;
          importedSimpleToFqn[simple] = fqn;
        }
      }

      // 变量到类映射（不依赖包前缀）
      final varToClass = <String, String>{};
      for (final line in lines) {
        // Java 变量声明
        final j = RegExp(r'^\s*(?:final\s+)?([A-Z][A-Za-z0-9_\.]+)\s+(\w+)\s*(?:=|;)').firstMatch(line);
        if (j != null) {
          final type = j.group(1)!;
          final varName = j.group(2)!;
          String? fqn;
          if (type.contains('.')) {
            fqn = type; // 已是 FQN
          } else {
            fqn = importedSimpleToFqn[type];
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
        // Kotlin 属性声明
        final k = RegExp(r'^\s*(val|var)\s+(\w+)\s*:\s*([A-Z][A-Za-z0-9_\.]+)').firstMatch(line);
        if (k != null) {
          final varName = k.group(2)!;
          final type = k.group(3)!;
          String? fqn;
          if (type.contains('.')) {
            fqn = type;
          } else {
            fqn = importedSimpleToFqn[type];
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
      }

      // 扫描调用
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        // 静态调用：ClassName.method(
        // 同时支持直接使用 FQN 进行静态调用
        // 仅在类名通过 imports 可解析到 FQN 或代码中直接是 FQN 时确认；避免与局部变量名冲突
        final staticCall = RegExp(r'\b([A-Z][A-Za-z0-9_\.]+)\.(\w+)\s*\(').firstMatch(line);
        if (staticCall != null) {
          final clsToken = staticCall.group(1)!;
          final method = staticCall.group(2)!;
          String? fqn;
          if (clsToken.contains('.')) {
            fqn = clsToken; // 代码中直接出现 FQN
          } else {
            fqn = importedSimpleToFqn[clsToken];
          }
          if (fqn != null && sdkClassSet.contains(fqn)) {
            final apis = sdkApisByClass[fqn] ?? const <SdkApi>[];
            for (final api in apis.where((a) => a.methodName == method)) {
              (usages[api] ??= []).add(CallSite(
                filePath: f.path,
                line: i + 1,
                lineText: line.trim(),
                kind: 'static',
              ));
            }
          }
        }

        // 实例调用：varName.method(，支持 Kotlin 安全调用 ?. 与 非空断言 !!.
        final instanceCall = RegExp(r'\b(\w+)(?:\?\.|!!\.|\.)\s*(\w+)\s*\(').firstMatch(line);
        if (instanceCall != null) {
          final varName = instanceCall.group(1)!;
          final method = instanceCall.group(2)!;
          final fqn = varToClass[varName];
          if (fqn != null && sdkClassSet.contains(fqn)) {
            final apis = sdkApisByClass[fqn] ?? const <SdkApi>[];
            for (final api in apis.where((a) => a.methodName == method)) {
              (usages[api] ??= []).add(CallSite(
                filePath: f.path,
                line: i + 1,
                lineText: line.trim(),
                kind: 'instance',
              ));
            }
          }
        }
      }
    }
    return usages;
  }

  // 仅通过包前缀分析项目的实际调用（不依赖 SDK 源码）
  Future<SdkAnalysisResult> analyzeUsageOnly({
    required String projectPath,
    required String sdkPackagePrefix,
  }) async {
    final errors = <String>[];
    final usages = await _collectProjectUsagesUsageOnly(
      projectPath: projectPath,
      sdkPackagePrefix: sdkPackagePrefix,
      errors: errors,
    );
    return SdkAnalysisResult(usages: usages, errors: errors);
  }

  Future<List<SdkApi>> _collectSdkApis(String sdkPath, List<String> errors) async {
    final result = <SdkApi>[];
    final dir = Directory(sdkPath);
    if (!dir.existsSync()) {
      errors.add('SDK 路径不存在：$sdkPath');
      return result;
    }
    final files = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.java') || f.path.endsWith('.kt'));

    for (final f in files) {
      final lines = <String>[];
      try {
        lines.addAll(await f.readAsLines());
      } catch (e) {
        errors.add('读取 SDK 文件失败：${f.path} · $e');
        continue;
      }
      String pkg = '';
      String cls = '';
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // package
        final pkgMatch = RegExp(r'^package\s+([\w\.]+)\s*;?').firstMatch(line);
        if (pkgMatch != null) {
          pkg = pkgMatch.group(1)!;
          continue;
        }
        // class/interface/enum (Java/Kotlin)
        final clsMatch = RegExp(r'^(public\s+)?(class|interface|enum)\s+(\w+)').firstMatch(line);
        if (clsMatch != null) {
          cls = clsMatch.group(3)!;
          continue;
        }
        // methods (Java)
        final mJava = RegExp(r'^(public|protected)\s+(static\s+)?[\w\<\>\[\]]+\s+(\w+)\s*\(').firstMatch(line);
        if (mJava != null && pkg.isNotEmpty && cls.isNotEmpty) {
          final name = mJava.group(3)!;
          final signature = lines[i].trim();
          result.add(SdkApi(package: pkg, className: cls, methodName: name, signature: signature));
          continue;
        }
        // methods (Kotlin)
        final mKt = RegExp(r'^(public\s+)?fun\s+(\w+)\s*\(').firstMatch(line);
        if (mKt != null && pkg.isNotEmpty && cls.isNotEmpty) {
          final name = mKt.group(2)!;
          final signature = lines[i].trim();
          result.add(SdkApi(package: pkg, className: cls, methodName: name, signature: signature));
          continue;
        }
      }
    }
    return result;
  }

  Future<Map<SdkApi, List<CallSite>>> _collectProjectUsages({
    required String projectPath,
    required String sdkPackagePrefix,
    required List<SdkApi> sdkApis,
    required List<String> errors,
  }) async {
    final usages = <SdkApi, List<CallSite>>{};
    final sdkApisByClass = <String, List<SdkApi>>{}; // FQN class -> apis
    for (final api in sdkApis) {
      final fqnClass = '${api.package}.${api.className}';
      (sdkApisByClass[fqnClass] ??= []).add(api);
    }

    final dir = Directory(projectPath);
    if (!dir.existsSync()) {
      errors.add('项目路径不存在：$projectPath');
      return usages;
    }
    final files = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.java') || f.path.endsWith('.kt'));

    for (final f in files) {
      List<String> lines;
      try {
        lines = await f.readAsLines();
      } catch (e) {
        errors.add('读取项目文件失败：${f.path} · $e');
        continue;
      }

      // collect imports under sdk package
      final importedClasses = <String>{}; // FQN
      for (final line in lines) {
        final m = RegExp(r'^\s*import\s+([\w\.]+)\s*;?').firstMatch(line);
        if (m != null) {
          final fqn = m.group(1)!;
          if (fqn.startsWith(sdkPackagePrefix)) {
            importedClasses.add(fqn);
          }
        }
      }
      if (importedClasses.isEmpty) continue; // skip files not importing sdk

      // build variable -> class mapping (simple heuristics)
      final varToClass = <String, String>{}; // var -> FQN class
      for (final line in lines) {
        // Java variable declaration
        final j = RegExp(r'^\s*(?:final\s+)?([A-Z][A-Za-z0-9_\.]+)\s+(\w+)\s*(?:=|;)').firstMatch(line);
        if (j != null) {
          final type = j.group(1)!;
          final varName = j.group(2)!;
          // If type is simple class name, resolve via imports
          String? fqn;
          if (type.contains('.')) {
            fqn = type; // already FQN
          } else {
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.$type'),
              orElse: () => '',
            );
            if (fqn.isEmpty) fqn = null;
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
        // Kotlin property declaration
        final k = RegExp(r'^\s*(val|var)\s+(\w+)\s*:\s*([A-Z][A-Za-z0-9_\.]+)').firstMatch(line);
        if (k != null) {
          final varName = k.group(2)!;
          final type = k.group(3)!;
          String? fqn;
          if (type.contains('.')) {
            fqn = type;
          } else {
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.$type'),
              orElse: () => '',
            );
            if (fqn.isEmpty) fqn = null;
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
        // Kotlin 类型推断：val x = ClassName(...)/ClassName.getInstance(...)
        final kInfer = RegExp(r'^\s*(val|var)\s+(\w+)\s*=\s*([A-Z][A-Za-z0-9_\.]+)\s*(?:\(|\.)').firstMatch(line);
        if (kInfer != null) {
          final varName = kInfer.group(2)!;
          final typeToken = kInfer.group(3)!;
          String? fqn;
          if (typeToken.contains('.')) {
            // 可能是 FQN 或包前缀 + 类名
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.' + typeToken.split('.').last),
              orElse: () => '',
            );
            if (fqn.isEmpty) {
              fqn = typeToken; // 直接使用 FQN
            }
          } else {
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.$typeToken'),
              orElse: () => '',
            );
            if (fqn.isEmpty) fqn = null;
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
      }

      // scan for usages
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // static/class calls: ClassName.method(
        for (final fqn in importedClasses) {
          final cls = fqn.split('.').last;
          final staticCall = RegExp(r'\b' + RegExp.escape(cls) + r'\.(\w+)\s*\(').firstMatch(line);
          if (staticCall != null) {
            final method = staticCall.group(1)!;
            final apis = sdkApisByClass[fqn] ?? const <SdkApi>[];
            for (final api in apis.where((a) => a.methodName == method)) {
              (usages[api] ??= []).add(CallSite(
                filePath: f.path,
                line: i + 1,
                lineText: line.trim(),
                kind: 'static',
              ));
            }
          }
        }
        // instance calls: varName.method(，支持 Kotlin 安全调用 ?. 与 非空断言 !!.
        final instanceCall = RegExp(r'\b(\w+)(?:\?\.|!!\.|\.)\s*(\w+)\s*\(').firstMatch(line);
        if (instanceCall != null) {
          final varName = instanceCall.group(1)!;
          final method = instanceCall.group(2)!;
          final fqn = varToClass[varName];
          if (fqn != null) {
            final apis = sdkApisByClass[fqn] ?? const <SdkApi>[];
            for (final api in apis.where((a) => a.methodName == method)) {
              (usages[api] ??= []).add(CallSite(
                filePath: f.path,
                line: i + 1,
                lineText: line.trim(),
                kind: 'instance',
              ));
            }
          }
        }
      }
    }
    return usages;
  }

  // 用于仅根据包前缀提取调用：不需要 SDK 方法签名，直接根据实例/静态调用行生成 API 键
  Future<Map<SdkApi, List<CallSite>>> _collectProjectUsagesUsageOnly({
    required String projectPath,
    required String sdkPackagePrefix,
    required List<String> errors,
  }) async {
    final usages = <SdkApi, List<CallSite>>{};
    final dir = Directory(projectPath);
    if (!dir.existsSync()) {
      errors.add('项目路径不存在：$projectPath');
      return usages;
    }
    final files = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.java') || f.path.endsWith('.kt'));

    for (final f in files) {
      List<String> lines;
      try {
        lines = await f.readAsLines();
      } catch (e) {
        errors.add('读取项目文件失败：${f.path} · $e');
        continue;
      }

      // 收集 SDK 包前缀下的 import 类
      final importedClasses = <String>{}; // FQN
      for (final line in lines) {
        final m = RegExp(r'^\s*import\s+([\w\.]+)\s*;?').firstMatch(line);
        if (m != null) {
          final fqn = m.group(1)!;
          if (fqn.startsWith(sdkPackagePrefix)) {
            importedClasses.add(fqn);
          }
        }
      }
      if (importedClasses.isEmpty) continue;

      // 变量到类映射（简单推断）
      final varToClass = <String, String>{};
      for (final line in lines) {
        final j = RegExp(r'^\s*(?:final\s+)?([A-Z][A-Za-z0-9_\.]+)\s+(\w+)\s*(?:=|;)').firstMatch(line);
        if (j != null) {
          final type = j.group(1)!;
          final varName = j.group(2)!;
          String? fqn;
          if (type.contains('.')) {
            fqn = type;
          } else {
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.$type'),
              orElse: () => '',
            );
            if (fqn.isEmpty) fqn = null;
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
        final k = RegExp(r'^\s*(val|var)\s+(\w+)\s*:\s*([A-Z][A-Za-z0-9_\.]+)').firstMatch(line);
        if (k != null) {
          final varName = k.group(2)!;
          final type = k.group(3)!;
          String? fqn;
          if (type.contains('.')) {
            fqn = type;
          } else {
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.$type'),
              orElse: () => '',
            );
            if (fqn.isEmpty) fqn = null;
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
        // Kotlin 类型推断：val x = ClassName(...)/ClassName.getInstance(...)
        final kInfer = RegExp(r'^\s*(val|var)\s+(\w+)\s*=\s*([A-Z][A-Za-z0-9_\.]+)\s*(?:\(|\.)').firstMatch(line);
        if (kInfer != null) {
          final varName = kInfer.group(2)!;
          final typeToken = kInfer.group(3)!;
          String? fqn;
          if (typeToken.contains('.')) {
            // 可能是 FQN 或包前缀 + 类名
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.' + typeToken.split('.').last),
              orElse: () => '',
            );
            if (fqn.isEmpty) {
              fqn = typeToken; // 直接使用 FQN
            }
          } else {
            fqn = importedClasses.firstWhere(
              (c) => c.endsWith('.$typeToken'),
              orElse: () => '',
            );
            if (fqn.isEmpty) fqn = null;
          }
          if (fqn != null) varToClass[varName] = fqn;
        }
      }

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 静态调用：ClassName.method(
        for (final fqn in importedClasses) {
          final cls = fqn.split('.').last;
          final staticCall = RegExp(r'\b' + RegExp.escape(cls) + r'\.(\w+)\s*\(').firstMatch(line);
          if (staticCall != null) {
            final method = staticCall.group(1)!;
            final api = SdkApi(
              package: fqn.substring(0, fqn.lastIndexOf('.')),
              className: cls,
              methodName: method,
              signature: line.trim(),
            );
            (usages[api] ??= []).add(CallSite(
              filePath: f.path,
              line: i + 1,
              lineText: line.trim(),
              kind: 'static',
            ));
          }
        }
        // 实例调用：varName.method(，支持 Kotlin 安全调用 ?. 与 非空断言 !!.
        final instanceCall = RegExp(r'\b(\w+)(?:\?\.|!!\.|\.)\s*(\w+)\s*\(').firstMatch(line);
        if (instanceCall != null) {
          final varName = instanceCall.group(1)!;
          final method = instanceCall.group(2)!;
          final fqn = varToClass[varName];
          if (fqn != null) {
            final cls = fqn.split('.').last;
            final api = SdkApi(
              package: fqn.substring(0, fqn.lastIndexOf('.')),
              className: cls,
              methodName: method,
              signature: line.trim(),
            );
            (usages[api] ??= []).add(CallSite(
              filePath: f.path,
              line: i + 1,
              lineText: line.trim(),
              kind: 'instance',
            ));
          }
        }
      }
    }
    return usages;
  }

  // 解压 .aar 中的 classes.jar 到临时目录，返回 classes.jar 路径
  Future<String> _extractClassesJarFromAar(String aarPath) async {
    final tmp = Directory.systemTemp.createTempSync('jarvis_aar_');
    final out = await Process.run(
      'unzip',
      ['-o', aarPath, 'classes.jar', '-d', tmp.path],
    );
    if (out.exitCode != 0) {
      throw Exception('解压 classes.jar 失败：${out.stderr}\n${out.stdout}');
    }
    final jarFile = File('${tmp.path}/classes.jar');
    if (!jarFile.existsSync()) {
      throw Exception('未在 AAR 中找到 classes.jar');
    }
    return jarFile.path;
  }

  // 通过 jar tf + javap 提取 jar 中指定包前缀的公开/受保护方法
  Future<SdkApiCollectResult> _collectSdkApisFromJar(
    String classesJarPath,
  ) async {
    final apis = <SdkApi>[];
    final errors = <String>[];

    // 列出所有 class
    final list = await Process.run('jar', ['tf', classesJarPath]);
    if (list.exitCode != 0) {
      errors.add('列出 Jar 内容失败：${list.stderr}');
      return SdkApiCollectResult(apis: apis, errors: errors);
    }
    final entries = (list.stdout as String)
        .split('\n')
        .where((e) => e.endsWith('.class'))
        .where((e) => !e.startsWith('META-INF/'))
        .toList();

    // 不提前按路径过滤，逐类解析后按包前缀筛选，避免路径差异导致漏检
    final classes = entries
        .map((e) => e.replaceAll('/', '.').replaceAll('.class', ''))
        .toList();

    for (final fqn in classes) {
      final dotIdx = fqn.lastIndexOf('.');
      if (dotIdx <= 0) continue; // 跳过无包名的类
      final pkg = fqn.substring(0, dotIdx);
      final cls = fqn.substring(dotIdx + 1); // 包含 $Inner

      final decomp = await Process.run(
        'javap',
        ['-classpath', classesJarPath, '-protected', fqn],
      );
      if (decomp.exitCode != 0) {
        errors.add('javap 失败：$fqn · ${decomp.stderr}');
        continue;
      }
      final lines = (decomp.stdout as String).split('\n');
      for (final line in lines) {
        final t = line.trim();
        if (!t.contains('(')) continue; // 排除字段
        final idxParen = t.indexOf('(');
        final left = t.substring(0, idxParen).trim();
        final lastSpace = left.lastIndexOf(' ');
        final method = lastSpace >= 0 ? left.substring(lastSpace + 1) : left;
        if (method == cls || method == '<init>' || method.startsWith(r'access$') || method.startsWith(r'lambda$')) {
          continue; // 排除构造与合成方法
        }
        final isPublic = t.startsWith('public');
        final isProtected = t.startsWith('protected');
        if (!isPublic && !isProtected) continue;
        apis.add(SdkApi(
          package: pkg,
          className: cls,
          methodName: method,
          signature: t,
        ));
      }
    }
    return SdkApiCollectResult(apis: apis, errors: errors);
  }
}

class ProjectDependency {
  final String module;      // artifact 名称（name）
  final String group;       // group
  final String version;     // 版本
  final String artifactPath; // 本地缓存中的 aar/jar 路径
  final String kind;        // 'aar' | 'jar'

  const ProjectDependency({
    required this.module,
    required this.group,
    required this.version,
    required this.artifactPath,
    required this.kind,
  });

  @override
  String toString() => '$group:$module:$version · $kind · $artifactPath';
}

class DependencyCoord {
  final String group;
  final String name;
  final String version;

  const DependencyCoord(this.group, this.name, this.version);

  @override
  bool operator ==(Object other) {
    return other is DependencyCoord &&
        other.group == group &&
        other.name == name &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(group, name, version);
}