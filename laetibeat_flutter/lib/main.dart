import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart';
import 'package:laetibeat/src/rust/frb_generated.dart';
import 'nav_shell.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return M3EMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laetibeat',
      data: M3EThemeData.light(
        seedColor: const Color(0xFF6750A4),
      ),
      home: const NavShell(),
    );
  }
}

