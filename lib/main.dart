import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'rooms.dart';
import 'util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  askForNotificationPermission();
  ThemeData theme = await getThemePreference();
  saveRegistrationToken();
  runApp(MyApp(theme: theme));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Shield Talk',
        themeMode: theme == ThemeData.dark() ? ThemeMode.dark : ThemeMode.light,
        home: RoomsPage(theme: theme),
      );
}
