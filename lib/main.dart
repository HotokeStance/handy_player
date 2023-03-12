import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:handy_player/modules/loading/loading_state_notifier.dart';
import 'package:handy_player/modules/search/search_screen.dart';
import 'package:handy_player/modules/service_locator.dart';
import 'package:handy_player/screens/downloads_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final loadingStateNotifier =
    StateNotifierProvider<LoadingStateNotifier, bool>((ref) {
  return LoadingStateNotifier();
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initServiceLocator();
  await dotenv.load(fileName: ".env");
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends HookConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(loadingStateNotifier);
    return MaterialApp(
      title: 'YoutubePlayer',
      theme: ThemeData.dark(),
      home: const MyHomePage(title: 'YoutubePlayer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();

    Future(() async {
      // アプリ起動時の権限チェック
      await Permission.storage.request();
    });
  }

  static const _screens = [
    SearchScreen(),
    DownloadsScreen(),
  ];

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.download), label: 'downloads'),
        ],
      ),
    );
  }
}
