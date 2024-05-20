import 'package:ai_chat/main.dart';
import 'package:ai_chat/services/listening_service.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case "voiceDetectionTask":
        final listeningService = getIt<ListeningService>();
        await listeningService.initSpeech();
        listeningService.startListening();
        break;
      default:
        print("Task không hợp lệ: $task");
    }
    return Future.value(true);
  });
}

void initializeWorkManager() {
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Đặt là false cho production
  );
}

void scheduleVoiceDetectionTask() {
  Workmanager().registerPeriodicTask(
    "1", // ID duy nhất cho task
    "voiceDetectionTask", // Tên task
    frequency: const Duration(minutes: 15), // Tần suất lặp lại task (tối thiểu 15 phút)
    initialDelay: const Duration(seconds: 10), // Delay ban đầu trước khi task chạy lần đầu
    constraints: Constraints(
      networkType: NetworkType.connected, // Chỉ chạy khi có kết nối mạng
    ),
  );
}