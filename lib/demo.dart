import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WordToSentencePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WordToSentencePage extends StatefulWidget {
  @override
  State<WordToSentencePage> createState() => _WordToSentencePageState();
}

class _WordToSentencePageState extends State<WordToSentencePage> {
  final TextEditingController _controller = TextEditingController();
  String result = '';

  final String apiKey = "AIzaSyCtfaAlECW5JGLrVaKmw3MFCpg18VLiBEE";

  Future<void> listModels() async {
    setState(() => result = "Fetching models...");

    try {
      final response = await http.get(
        Uri.parse(
            "https://generativelanguage.googleapis.com/v1/models?key=$apiKey"),
      );

      final data = json.decode(response.body);
      setState(() => result = const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      setState(() => result = "Model list failed.");
    }
  }

  Future<void> sendWord() async {
    final word = _controller.text.trim();

    if (word.isEmpty) {
      setState(() => result = "Please enter a word.");
      return;
    }

    setState(() => result = "Working on it...");

    final url =
        "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "contents": [
            {
              "parts": [
                {"text": "Create a sentence using this word: $word"}
              ]
            }
          ]
        }),
      );

      final data = json.decode(response.body);

      final text = data["candidates"]?[0]?["content"]?["parts"]?[0]?
              ["text"] ??
          data["candidates"]?[0]?["output"] ??
          "No response.";

      setState(() => result = text);
    } catch (e) {
      setState(() => result = "Something broke. Possibly everything.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Word to Sentence")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Enter a word",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                    onPressed: sendWord, child: const Text("Send")),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: listModels, child: const Text("List Models")),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Result:"),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5)
                    ]),
                child: SingleChildScrollView(child: Text(result)),
              ),
            )
          ],
        ),
      ),
    );
  }
}