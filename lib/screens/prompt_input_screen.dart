import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../services/api_services.dart';
import '../screens/answer_display_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class PromptInputScreen extends StatefulWidget {
  final bool showTutorial;
  const PromptInputScreen({Key? key, this.showTutorial = false}) : super(key: key);

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

  // Global keys for tutorial targets.
  final GlobalKey _plantNameFieldKey = GlobalKey();
  final GlobalKey _plantMicKey = GlobalKey();
  final GlobalKey _complaintFieldKey = GlobalKey();
  final GlobalKey _complaintMicKey = GlobalKey();
  final GlobalKey _photoPickerKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;
  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();

    // If showTutorial is true (navigated via cue card), display the overlay.
    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initTargets();
        _showTutorialCoachMark();
      });
    }
  }

  void _initTargets() {
    targets.clear();
    targets.add(
      TargetFocus(
        identify: "PlantNameField",
        keyTarget: _plantNameFieldKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Container(
              child: const Text(
                "Tuliskan nama tanaman di sini.",
                style: TextStyle(color: Colors.black, fontSize: 24),
              ),
            ),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "PlantMic",
        keyTarget: _plantMicKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              child: const Text(
                "Tekan tombol ini untuk menggunakan fitur rekam suara, katakan nama tanaman.",
                style: TextStyle(color: Colors.black, fontSize: 24),
              ),
            ),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "ComplaintField",
        keyTarget: _complaintFieldKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              child: const Text(
                "Masukan keluhan tentang tanaman anda di sini.",
                style: TextStyle(color: Colors.black, fontSize: 24),
              ),
            ),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "ComplaintMic",
        keyTarget: _complaintMicKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              child: const Text(
                "Tekan tombol ini untuk menggunakan fitur rekam suara keluhan tanaman anda.",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "PhotoPicker",
        keyTarget: _photoPickerKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              child: const Text(
                "Fitur ini untuk memberikan saya konteks tambahan dari gambar yang diberikan.",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTutorialCoachMark() {
    tutorialCoachMark = TutorialCoachMark(
      // Pass context as a positional argument.
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Prompt Input Tutorial finished");
        return true;
      },
      onSkip: () {
        print("Prompt Input Tutorial skipped");
        return true;
      },
    )..show(context:context);
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

  /// Pick or capture an image.
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
      final result = await ApiServices.sendChatPromptMultipart(
        plantName: plantName,
        complaint: complaint,
        imageFile: _selectedImageFile,
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

  // Rewritten getters with explicit return.
  bool get _isRecordingPlant {
    return _activeMic == 'plant' && (_recorder != null ? _recorder!.isRecording : false);
  }

  bool get _isRecordingComplaint {
    return _activeMic == 'complaint' && (_recorder != null ? _recorder!.isRecording : false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Konsultasi"),
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
                  // Plant name row with key.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          key: _plantNameFieldKey,
                          child: _buildTextField(
                            label: "Nama Tanaman",
                            controller: _plantNameController,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: _plantMicKey,
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
                  // Complaint row with key.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          key: _complaintFieldKey,
                          child: _buildTextField(
                            label: "Keluhan",
                            controller: _complaintController,
                            maxLines: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: _complaintMicKey,
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
                  // Image preview and photo picker with key.
                  Container(
                    key: _photoPickerKey,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
