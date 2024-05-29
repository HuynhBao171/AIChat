import 'package:ai_chat/main.dart';
import 'package:ai_chat/services/background_service.dart';
import 'package:ai_chat/services/deepgram_service.dart';
import 'package:ai_chat/services/gemini_service.dart';
import 'package:ai_chat/services/listening_service.dart';
import 'package:ai_chat/services/speaking_servive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ListeningService listeningService = getIt<ListeningService>();
  final SpeakingService speakingService = getIt<SpeakingService>();
  final DeepgramService deepgramService = getIt<DeepgramService>();
  final GeminiService gemini = getIt<GeminiService>();

  bool loading = false;
  bool isListening = false;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    // Khởi tạo speaking service và Gemini
    speakingService.initTts();
    super.initState();
    // Lời chào từ Gemini
    chatStream.sink.add([
      {
        "role": "Gemini",
        "text": "Hello! I'm here to help you.",
      },
    ]);
    // speakingService.speak(chatStream.stream.value[0]['text']!);
    deepgramService.speakFromText(chatStream.stream.value[0]['text']!);
    isListening = !isListening;
    // listeningService.initSpeech();
  }

  @override
  void dispose() {
    // Ngừng lắng nghe khi dispose
    listeningService.stopListening();
    chatStream.close(); // Đóng stream khi dispose
    super.dispose();
  }

  void fromText({required String query, required String user}) {
    setState(() {
      loading = true;
      // Thêm tin nhắn người dùng vào stream
      chatStream.sink.add([
        ...chatStream.stream.value,
        {
          "role": user,
          "text": query,
        },
      ]);
      // Clear the text field
      _textController.clear();
    });
    scrollToTheEnd();

    gemini.generateFromText(query).then((value) {
      setState(() {
        loading = false;
        // Thêm tin nhắn Gemini vào stream
        chatStream.sink.add([
          ...chatStream.value,
          {
            "role": "Gemini",
            "text": value.text,
          },
        ]);
      });
      scrollToTheEnd();
      speakingService.speak(value.text);
    }).catchError((error, stackTrace) {
      setState(() {
        loading = false;
        // Thêm lỗi vào stream
        chatStream.sink.add([
          ...chatStream.stream.value,
          {
            "role": "Gemini",
            "text": error.toString(),
          },
        ]);
      });
      scrollToTheEnd();
      speakingService.speak(error.toString());
    });
  }

  void scrollToTheEnd() {
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Main Screen'),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text('Drawer Header'),
              ),
              ListTile(
                title: ElevatedButton(
                  child: const Text("Turn on background service"),
                  onPressed: () async {
                    await backgroundService();
                  },
                ),
              ),
              ListTile(
                title: ElevatedButton(
                  child: const Text("Set As Foreground"),
                  onPressed: () {
                    FlutterBackgroundService().invoke("setAsForeground");
                  },
                ),
              ),
              ListTile(
                title: ElevatedButton(
                  child: const Text("Set As Background"),
                  onPressed: () {
                    FlutterBackgroundService().invoke("setAsBackground");
                  },
                ),
              ),
              ListTile(
                title: ElevatedButton(
                  child: const Text("Stop Service"),
                  onPressed: () async {
                    FlutterBackgroundService().invoke("stopService");
                  },
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, String>>>(
                stream: chatStream.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final chatData = snapshot.data!;
                    return ListView.builder(
                      controller: _controller,
                      itemCount: chatData.length,
                      padding: const EdgeInsets.only(bottom: 20),
                      itemBuilder: (context, index) {
                        final role = chatData[index]["role"] ?? "";
                        final text = chatData[index]["text"] ?? "";
                        return ListTile(
                          isThreeLine: true,
                          leading: CircleAvatar(
                            child: Text(role.substring(0, 1)),
                          ),
                          title: Text(role),
                          subtitle: Text(text),
                        );
                      },
                    );
                  } else {
                    return const Center(
                        child: CircularProgressIndicator()); // Hiển thị loading
                  }
                },
              ),
            ),
            Container(
              alignment: Alignment.bottomRight,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: StreamBuilder<String>(
                      // stream: listeningService.speechSubject
                      //     .stream, // Sử dụng _speechSubject.stream
                      stream: textStream.stream,
                      builder: (context, snapshot) {
                        _textController.text = snapshot.data ?? '';
                        return TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: "Write a message",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: BorderSide.none),
                            fillColor: Colors.transparent,
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: isListening
                        ? const Icon(Icons.mic)
                        : const Icon(Icons.mic_off),
                    onPressed: () {
                      setState(() {
                        isListening = !isListening;
                        if (isListening) {
                          // listeningService.startListening();
                          deepgramService.startStream();
                        } else {
                          // listeningService.stopListening();
                          deepgramService.stopStream();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: loading
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.send),
                    onPressed: () {
                      fromText(query: _textController.text, user: 'User');
                    },
                  ),
                ],
              ),
            )
          ],
        ));
  }
}
