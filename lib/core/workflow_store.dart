import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkflowConfig {
  final String id;
  final String name;
  final String? description;
  final List<String> platforms; // e.g. ["macos", "linux"]
  final String triggerType; // "manual" | "schedule"
  final String? cron; // when triggerType == "schedule"
  final List<String> steps; // simple representation of actions
  final String? template; // optional template key
  final DateTime createdAt;

  const WorkflowConfig({
    required this.id,
    required this.name,
    this.description,
    this.platforms = const [],
    this.triggerType = 'manual',
    this.cron,
    this.steps = const [],
    this.template,
    required this.createdAt,
  });

  WorkflowConfig copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? platforms,
    String? triggerType,
    String? cron,
    List<String>? steps,
    String? template,
    DateTime? createdAt,
  }) {
    return WorkflowConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      platforms: platforms ?? this.platforms,
      triggerType: triggerType ?? this.triggerType,
      cron: cron ?? this.cron,
      steps: steps ?? this.steps,
      template: template ?? this.template,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'platforms': platforms,
        'triggerType': triggerType,
        'cron': cron,
        'steps': steps,
        'template': template,
        'createdAt': createdAt.toIso8601String(),
      };

  static WorkflowConfig fromJson(Map<String, dynamic> json) {
    return WorkflowConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      platforms: (json['platforms'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      triggerType: json['triggerType'] as String? ?? 'manual',
      cron: json['cron'] as String?,
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      template: json['template'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class WorkflowStore {
  static const _prefsKey = 'jarvis_workflows_v1';
  static final WorkflowStore instance = WorkflowStore._();

  final ValueNotifier<List<WorkflowConfig>> workflows =
      ValueNotifier<List<WorkflowConfig>>(<WorkflowConfig>[]);

  WorkflowStore._();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      workflows.value = <WorkflowConfig>[];
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      workflows.value = decoded
          .map((e) => WorkflowConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // fallback on parse error
      workflows.value = <WorkflowConfig>[];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(workflows.value.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> add(WorkflowConfig config) async {
    workflows.value = [...workflows.value, config];
    await _persist();
  }

  Future<void> update(WorkflowConfig config) async {
    workflows.value = workflows.value.map((e) => e.id == config.id ? config : e).toList();
    await _persist();
  }

  Future<void> remove(String id) async {
    workflows.value = workflows.value.where((e) => e.id != id).toList();
    await _persist();
  }

  WorkflowConfig? getById(String id) {
    try {
      return workflows.value.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}