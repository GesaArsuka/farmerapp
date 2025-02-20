import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_services.dart';
import '../screens/answer_display_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class PromptInputScreen extends StatefulWidget {
  const PromptInputScreen({Key? key}) : super(key: key);

  @override
  State<PromptInputScreen> createState() => _PromptInputScreenState();
}

class _PromptInputScreenState extends State<PromptInputScreen> {
  // For bottom nav highlighting the "Prompt" tab
  int _selectedIndex = 1;

  // Loading indicator for the GPT call
  bool _isLoading = false;

  // Text controllers
  final TextEditingController _plantNameController = TextEditingController();
  final TextEditingController _complaintController = TextEditingController();

  // FlutterSound recorder
  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;

  // Which mic are we currently recording for? 'plant' or 'complaint'
  String? _activeMic;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
  }

  /// Initialize the recorder and request permissions
  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denied
      return;
    }

    await _recorder!.openRecorder();
    setState(() {
      _isRecorderInitialized = true;
    });
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  /// Toggle recording for plant name or complaint
  Future<void> _toggleRecord(String target) async {
    if (!_isRecorderInitialized) return;

    if (_activeMic == null) {
      // Start recording for this target
      _activeMic = target;
      await _recorder!.startRecorder(toFile: "planting_assist_${target}.aac");
      setState(() {});
    } else if (_activeMic == target) {
      // Stop and transcribe
      final path = await _recorder!.stopRecorder();
      _activeMic = null;
      setState(() {});

      if (path != null) {
        final file = File(path);
        try {
          // Send to Whisper
          final transcription = await ApiServices.transcribeAudio(file);
          // Update the correct text field
          if (target == 'plant') {
            _plantNameController.text = transcription;
          } else {
            _complaintController.text = transcription;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Transcription error: $e")),
          );
        }
      }
    } else {
  // If a different mic was active, stop it first
  final path = await _recorder!.stopRecorder();
  _activeMic = null;
  setState(() {});

  // If we have a path, transcribe that leftover audio too
  if (path != null) {
    final file = File(path);
    try {
      final leftoverTranscription = await ApiServices.transcribeAudio(file);
      // Decide what to do with leftoverTranscription
      // e.g., show a dialog or store it somewhere
      print("Leftover transcription: $leftoverTranscription");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Leftover transcription error: $e")),
      );
    }
  }

  // Then start a new recording
  await _toggleRecord(target);
}
  }

  /// Combine plant and complaint text, send to GPT
  Future<void> _handleSubmit() async {
    final plantName = _plantNameController.text.trim();
    final complaint = _complaintController.text.trim();

    if (plantName.isEmpty && complaint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in at least one field")),
      );
      return;
    }

    final combinedPrompt = "Plant Name: $plantName\nComplaint: $complaint";

    setState(() => _isLoading = true);
    try {
      final gptResponse = await ApiServices.sendChatPrompt(combinedPrompt);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnswerDisplayScreen(
            plantName: plantName,
            complaint: complaint,
            initialAnswer: gptResponse,
          ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $error")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool get _isRecordingPlant =>
      _activeMic == 'plant' && _recorder!.isRecording;
  bool get _isRecordingComplaint =>
      _activeMic == 'complaint' && _recorder!.isRecording;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verdant"),
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  // Plant Name row (TextField + Mic)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: "Nama Tanaman",
                          controller: _plantNameController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _isRecordingPlant ? Icons.mic : Icons.mic_none,
                          color: _isRecordingPlant ? Colors.red : Colors.grey,
                        ),
                        onPressed: _isRecorderInitialized
                            ? () => _toggleRecord('plant')
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Complaint row (TextField + Mic)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: "Keluhan",
                          controller: _complaintController,
                          maxLines: 5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _isRecordingComplaint ? Icons.mic : Icons.mic_none,
                          color: _isRecordingComplaint ? Colors.red : Colors.grey,
                        ),
                        onPressed: _isRecorderInitialized
                            ? () => _toggleRecord('complaint')
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: const Text("Kirim"),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),

      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.pushNamed(context, '/mainFeatures');
          } else if (index == 1) {
            // Already on Prompt
          } else if (index == 2) {
            Navigator.pushNamed(
              context,
              '/answerDisplay',
              arguments: {
                'plantName': 'Placeholder Plant',
                'complaint': 'Placeholder Complaint',
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
