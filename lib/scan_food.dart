import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'services/ai_service.dart';
import 'services/user_profile_service.dart';
import 'result.dart';

// Color Palette (same as home.dart)
const Color primaryGreen = Color(0xFF00796B);
const Color primaryDark = Color(0xFF00796B);
const Color primaryLight = Color(0xFF4DB6AC);
const Color backgroundLight = Color(0xFFF0F4F7);
const Color cardWhite = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF212121);
const Color textLight = Color(0xFF757575);
const Color shadowDark = Color(0xFFC5DDE8);

class ScanFoodPage extends StatefulWidget {
  final VoidCallback? onScanComplete;
  
  const ScanFoodPage({super.key, this.onScanComplete});

  @override
  State<ScanFoodPage> createState() => _ScanFoodPageState();
}

class _ScanFoodPageState extends State<ScanFoodPage> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;
  bool isProcessing = false;
  String extractedText = '';
  File? capturedImage;
  final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _cameraController = CameraController(
          cameras![0], // Use the first (back) camera
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: $e')),
        );
      }
    }
  }

  Future<void> _captureAndExtractText() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      setState(() => isProcessing = true);

      // Capture image from camera
      final XFile imageFile = await _cameraController!.takePicture();
      final File file = File(imageFile.path);

      // Crop the image to the scan frame area before OCR
      final File? croppedFile = await _cropImageToScanFrame(file);
      final File fileToProcess = croppedFile ?? file;

      // Perform text recognition on cropped image
      final inputImage = InputImage.fromFile(fileToProcess);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      setState(() {
        capturedImage = file; // Show original image in preview
        extractedText = recognizedText.text;
        isProcessing = false;
      });

      // Show result in a dialog
      _showExtractedTextDialog();
    } catch (e) {
      print('Error capturing/processing image: $e');
      if (mounted) {
        setState(() => isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  /// Crops the captured image to match the scan frame area visible on screen.
  /// This ensures only text within the frame is processed by OCR.
  Future<File?> _cropImageToScanFrame(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Get screen dimensions
      final screenSize = MediaQuery.of(context).size;

      // Calculate the scan frame size (same calculation as in build method)
      final scanAreaSize = (screenSize.width * 0.35).clamp(250.0, 320.0);

      // Get camera preview dimensions
      final cameraValue = _cameraController!.value;
      final previewSize = cameraValue.previewSize!;

      // The camera preview fills the screen, so we need to calculate how the preview
      // is scaled/cropped to fit the screen
      final previewAspectRatio = previewSize.height / previewSize.width; // Rotated 90 degrees
      final screenAspectRatio = screenSize.width / screenSize.height;

      double scaleX, scaleY;
      double offsetX = 0, offsetY = 0;

      // Camera preview is typically shown in "cover" mode (fills screen, may crop edges)
      if (previewAspectRatio > screenAspectRatio) {
        // Preview is wider than screen, sides are cropped
        scaleY = originalImage.height / screenSize.height;
        scaleX = scaleY;
        offsetX = (originalImage.width - screenSize.width * scaleX) / 2;
      } else {
        // Preview is taller than screen, top/bottom are cropped
        scaleX = originalImage.width / screenSize.width;
        scaleY = scaleX;
        offsetY = (originalImage.height - screenSize.height * scaleY) / 2;
      }

      // Calculate the scan frame position on screen (centered)
      final scanFrameLeft = (screenSize.width - scanAreaSize) / 2;
      final scanFrameTop = (screenSize.height - scanAreaSize) / 2;

      // Convert screen coordinates to image coordinates
      // Add padding to capture slightly more area (10% extra on each side)
      final padding = scanAreaSize * 0.1;
      final cropLeft = ((scanFrameLeft - padding) * scaleX + offsetX).clamp(0.0, originalImage.width.toDouble()).toInt();
      final cropTop = ((scanFrameTop - padding) * scaleY + offsetY).clamp(0.0, originalImage.height.toDouble()).toInt();
      final cropWidth = ((scanAreaSize + padding * 2) * scaleX).clamp(1.0, originalImage.width.toDouble() - cropLeft).toInt();
      final cropHeight = ((scanAreaSize + padding * 2) * scaleY).clamp(1.0, originalImage.height.toDouble() - cropTop).toInt();

      // Ensure we have valid crop dimensions
      if (cropWidth <= 0 || cropHeight <= 0) return null;

      // Crop the image
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
      );

      // Save the cropped image to a temporary file
      final tempDir = await Directory.systemTemp.createTemp('scan_crop_');
      final croppedFile = File('${tempDir.path}/cropped_scan.jpg');
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 95));

      return croppedFile;
    } catch (e) {
      print('Error cropping image: $e');
      return null;
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() => isProcessing = true);

        final File file = File(pickedFile.path);
        final inputImage = InputImage.fromFile(file);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

        setState(() {
          capturedImage = file;
          extractedText = recognizedText.text;
          isProcessing = false;
        });

        _showExtractedTextDialog();
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        setState(() => isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  String _formatExtractedText(String rawText) {
    if (rawText.isEmpty) return 'No text detected';
    
    // Clean up the text
    String formatted = rawText
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .replaceAll(RegExp(r'\n+'), '\n') // Replace multiple newlines with single newline
        .trim();
    
    // Split into lines and clean each line
    List<String> lines = formatted.split('\n');
    List<String> cleanLines = [];
    
    for (String line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.isNotEmpty) {
        cleanLines.add(cleanLine);
      }
    }
    
    return cleanLines.join('\n');
  }

  Future<void> _analyzeWithAI() async {
    if (extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to analyze')),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: primaryGreen),
              const SizedBox(height: 16),
              Text(
                'Analyzing with AI...',
                style: TextStyle(color: textDark, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final userProfile = await UserProfileService.getUserProfile();
      final analysisResult = await AIService.analyzeFoodForUser(
        extractedText: extractedText,
        userProfile: userProfile,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        
        // Call the scan complete callback to deduct scan count
        widget.onScanComplete?.call();
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FoodAnalysisResultPage(
              scannedImage: capturedImage,
              extractedText: extractedText,
              analysisResult: analysisResult,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    }
  }

  void _showExtractedTextDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: cardWhite,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scanned Label Info',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: backgroundLight,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.close, color: textDark, size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Image preview
                  if (capturedImage != null)
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryLight, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          capturedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Extracted text section
                  Text(
                    'Extracted Text:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryLight.withOpacity(0.5)),
                    ),
                    child: Text(
                      extractedText.isNotEmpty ? _formatExtractedText(extractedText) : 'No text detected',
                      style: TextStyle(
                        fontSize: 14,
                        color: textDark,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              extractedText = '';
                              capturedImage = null;
                            });
                          },
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Scan Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: backgroundLight,
                            foregroundColor: primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: extractedText.isNotEmpty ? () => _analyzeWithAI() : null,
                          icon: const Icon(Icons.psychology_rounded),
                          label: const Text('Analyze with AI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: cardWhite,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraInitialized) {
      return Scaffold(
        backgroundColor: backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Food Label Scanner'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Food Label Scanner'),
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: Stack(
        children: [
          // Camera Preview
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_cameraController!),
          ),

          // Overlay with scanning hint
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Scanning frame box (responsive size)
                  Container(
                    width: (MediaQuery.of(context).size.width * 0.35).clamp(250.0, 320.0),
                    height: (MediaQuery.of(context).size.width * 0.35).clamp(250.0, 320.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: primaryLight,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Hint text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.camera_enhance_rounded,
                          color: primaryGreen,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Align food label within frame',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Make sure text is clear and well-lit',
                          style: TextStyle(
                            fontSize: 13,
                            color: textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action buttons
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Gallery button
                  Container(
                    decoration: BoxDecoration(
                      color: cardWhite,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isProcessing ? null : _pickImageFromGallery,
                        borderRadius: BorderRadius.circular(60),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.image_rounded,
                            color: primaryGreen,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Main capture button
                  GestureDetector(
                    onTap: isProcessing ? null : _captureAndExtractText,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: isProcessing
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(cardWhite),
                              strokeWidth: 2,
                            )
                          : Icon(
                              Icons.camera_alt_rounded,
                              color: cardWhite,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Placeholder for symmetry
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
