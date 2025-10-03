import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../core/utils/app_logger.dart';

class LogViewerScreen extends StatelessWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TalkerScreen(
      talker: AppLogger.talker,
      appBarTitle: 'APP LOG', // 自定义标题
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}