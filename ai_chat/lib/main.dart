import 'package:ai_chat/main_screen.dart';
import 'package:ai_chat/services/gemini_service.dart';
import 'package:ai_chat/services/listening_service.dart';
import 'package:ai_chat/services/speaking_servive.dart';
import 'package:ai_chat/services/workmanager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/web.dart';
import 'package:rxdart/rxdart.dart';

final getIt = GetIt.instance;
final chatStream = BehaviorSubject<List<Map<String, String>>>();

setupGetIt() async {
  getIt.registerSingleton<GeminiService>(GeminiService());
  getIt.registerSingleton<SpeakingService>(SpeakingService());
  getIt.registerSingleton<ListeningService>(ListeningService());
  getIt.registerLazySingleton<Logger>(() => Logger(
        printer: PrettyPrinter(
            methodCount: 2,
            errorMethodCount: 8,
            lineLength: 70,
            colors: true,
            printEmojis: true,
            printTime: false),
      ));
}

final logger = getIt<Logger>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupGetIt();
  await dotenv.load(fileName: ".env");
  initializeWorkManager();
  scheduleVoiceDetectionTask();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const MainScreen());
  }
}
