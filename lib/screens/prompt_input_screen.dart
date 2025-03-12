import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  int _selectedIndex = 1;
  bool _isLoading = false;

  final TextEditingController _plantNameController = TextEditingController();
  final TextEditingController _complaintController = TextEditingController();

  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;
  String? _activeMic;

  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
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

  Future<void> _toggleRecord(String target) async {
    if (!_isRecorderInitialized) return;

    if (_activeMic == null) {
      _activeMic = target;
      await _recorder!.startRecorder(toFile: "planting_assist_${target}.aac");
      setState(() {});
    } else if (_activeMic == target) {
      final path = await _recorder!.stopRecorder();
      _activeMic = null;
      setState(() {});
      if (path != null) {
        final file = File(path);
        try {
          final transcription = await ApiServices.transcribeAudio(file);
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
      final path = await _recorder!.stopRecorder();
      _activeMic = null;
      setState(() {});
      if (path != null) {
        final file = File(path);
        try {
          final leftoverTranscription = await ApiServices.transcribeAudio(file);
          print("Leftover transcription: $leftoverTranscription");
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Leftover transcription error: $e")),
          );
        }
      }
      await _toggleRecord(target);
    }
  }

  /// Pick or capture an image
  Future<void> _pickImage({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSubmit() async {
    final plantName = _plantNameController.text.trim();
    final complaint = _complaintController.text.trim();

    if (plantName.isEmpty || complaint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tolong masukkan keluhan dan nama tanaman.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the new multipart method in ApiServices.
      final result = await ApiServices.sendChatPromptMultipart(
        plantName: plantName,
        complaint: complaint,
        imageFile: _selectedImageFile,
        // conversationId: "some-existing-id" // if continuing a conversation
      );

      final gptResponse = result["answer"];
      final conversationId = result["conversation_id"];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnswerDisplayScreen(
            plantName: plantName,
            complaint: complaint,
            initialAnswer: gptResponse,
            conversationId: conversationId,
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

  bool get _isRecordingPlant => _activeMic == 'plant' && _recorder!.isRecording;
  bool get _isRecordingComplaint => _activeMic == 'complaint' && _recorder!.isRecording;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pertanyaan"),
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Plant name row
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

                  // Complaint row
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
                  const SizedBox(height: 20),

                  // Image preview
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _selectedImageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("No image selected."),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _pickImage(fromCamera: false),
                                    icon: const Icon(Icons.photo),
                                    label: const Text("Pick from Gallery"),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _pickImage(fromCamera: true),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text("Use Camera"),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedImageFile!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  color: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImageFile = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: const Text("Kirim"),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.pushNamed(context, '/mainFeatures');
          } else if (index == 1) {
            // Already on Prompt.
          } else if (index == 2) {
            Navigator.pushNamed(context, '/archivedConversations');
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
