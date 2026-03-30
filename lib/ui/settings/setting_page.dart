import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //顶栏
      appBar: AppBar(title: const Text("设置")),
      //内容
      body: const Center(child: Text("内容")),
    );
  }
}
