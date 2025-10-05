import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  final String message;
  const LoadingDialog({super.key, this.message = '正在加载...'});

  static void show(BuildContext context, {String message = '正在加载...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => LoadingDialog(message: message),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(40),
        backgroundColor: Colors.white,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8),
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 12),
              Text('正在加载...'),
            ],
          ),
        ),
      ),
    );
  }
}