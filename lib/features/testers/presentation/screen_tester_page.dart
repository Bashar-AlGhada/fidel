import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ScreenTesterPage extends StatefulWidget {
  const ScreenTesterPage({super.key});

  @override
  State<ScreenTesterPage> createState() => _ScreenTesterPageState();
}

class _ScreenTesterPageState extends State<ScreenTesterPage> {
  final List<Color> _colors = const [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.cyan,
    Color(0xFFFF00FF),
  ];
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final color = _colors[_index];
    final isDark = color.computeLuminance() < 0.5;
    final fg = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(title: Text('testers.screenTester'.tr)),
      body: GestureDetector(
        onTap: () => setState(() => _index = (_index + 1) % _colors.length),
        child: ColoredBox(
          color: color,
          child: Center(
            child: Text(
              'testers.tapToCycle'.tr,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
