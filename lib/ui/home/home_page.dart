import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';
import 'package:button_group_m3e/button_group_m3e.dart';
import 'package:laetibeat/ui/settings/setting_page.dart';

// 程序本身
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

//组件布局页面定义
class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //顶栏应用名+m3e按钮组[社区模块实现，未来官方实现替换]
        title: Text("Latebeat"),
        //按钮组
        actions: [
          Padding(
            padding: EdgeInsetsGeometry.only(right: 16),
            child: ButtonGroupM3E(
              type: ButtonGroupM3EType.connected,
              shape: ButtonGroupM3EShape.round,
              overflow: ButtonGroupM3EOverflow.menu,
              actions: [
                ButtonGroupM3EAction(label: Text("首页"), icon: Icon(Icons.home)),
                ButtonGroupM3EAction(
                  // 图标
                  label: const Icon(Icons.settings),

                  //点击动作
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),

      body: ListView(),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },

        //导航按钮
        height: 70,

        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: "主页"),
          NavigationDestination(icon: Icon(Icons.search), label: "搜索"),
          NavigationDestination(icon: Icon(Icons.library_music), label: "音乐库"),
        ],
      ),
    );
  }
}
