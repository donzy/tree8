import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(const ScreenRecorderApp());
}

class ScreenRecorderApp extends StatelessWidget {
  const ScreenRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const RecorderHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RecorderHomePage extends StatefulWidget {
  const RecorderHomePage({super.key});

  @override
  State<RecorderHomePage> createState() => _RecorderHomePageState();
}

class _RecorderHomePageState extends State<RecorderHomePage> {
  bool _isRecording = false;
  bool _isFloating = false;
  String _statusMessage = 'Ready to record';
  final String _apiBaseUrl = 'http://localhost:8080/api';

  @override
  void initState() {
    super.initState();
    _checkRecordingStatus();
  }

  Future<void> _checkRecordingStatus() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/status'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isRecording = data['is_recording'] ?? false;
          if (_isRecording) {
            _statusMessage = 'Recording in progress...';
          }
        });
      }
    } catch (e) {
      print('Error checking status: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/start-recording'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _isRecording = true;
            _statusMessage = 'Recording started';
            _isFloating = true;
          });
          
          // Switch to floating window mode
          await _switchToFloatingWindow();
        } else {
          setState(() {
            _statusMessage = data['message'] ?? 'Failed to start recording';
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/stop-recording'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _isRecording = false;
            _statusMessage = data['message'] ?? 'Recording stopped';
            _isFloating = false;
          });
          
          // Switch back to normal window mode
          await _switchToNormalWindow();
        } else {
          setState(() {
            _statusMessage = data['message'] ?? 'Failed to stop recording';
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      print('Error stopping recording: $e');
    }
  }

  Future<void> _switchToFloatingWindow() async {
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final screenWidth = primaryDisplay.size.width;
    final screenHeight = primaryDisplay.size.height;
    
    // Set window to circular floating window in bottom right corner
    await windowManager.setSize(const Size(120, 120));
    await windowManager.setPosition(
      Offset(screenWidth - 140, screenHeight - 140),
    );
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  }

  Future<void> _switchToNormalWindow() async {
    await windowManager.setSize(const Size(400, 600));
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFloating) {
      return _buildFloatingWindow();
    } else {
      return _buildMainWindow();
    }
  }

  Widget _buildMainWindow() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Recorder'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.videocam : Icons.videocam_off,
              size: 100,
              color: _isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 30),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  _isRecording ? 'Stop Recording' : 'Start Recording',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isRecording)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Recording... Click button to open floating window',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingWindow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _stopRecording,
          borderRadius: BorderRadius.circular(60),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
