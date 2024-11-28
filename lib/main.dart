import 'package:florafolium_app/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'dart:ui'; // Import for BackdropFilter
import 'dart:typed_data'; // Import for Float32List
import 'result_screen.dart';

List<CameraDescription> cameras = [];
var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const FloraFoliumApp());
}

class FloraFoliumApp extends StatelessWidget {
  const FloraFoliumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  XFile? imageFile;
  final ImagePicker _picker = ImagePicker();
  // Interpreter? _leafDetectorInterpreter; // Commented out leaf detector
  Interpreter? _leafClassifierInterpreter;
  // List<String> _detectorLabels = []; // Commented out detector labels
  List<String> _classifierLabels = [];
  bool _isLoading = false; // Loading state variable

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller?.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
    _loadModel(); // Changed to load only the classifier model
  }

  Future<void> _loadModel() async {
    try {
      // Load the leaf classifier model
      logger.i("Loading leaf classifier model...");
      _leafClassifierInterpreter =
          await Interpreter.fromAsset('assets/leafv7.tflite');
      _classifierLabels = await _loadLabels('assets/labels.txt');
      logger.i("Leaf classifier model and labels loaded successfully.");
    } catch (e) {
      logger.e("Failed to load model or labels: $e");
    }
  }

  Future<List<String>> _loadLabels(String filePath) async {
    try {
      final labelsData = await rootBundle.loadString(filePath);
      return labelsData.split('\n').where((label) => label.isNotEmpty).toList();
    } catch (e) {
      logger.e("Error loading labels from $filePath: $e");
      return [];
    }
  }

  Future<void> captureImage() async {
    if (controller?.value.isInitialized == true &&
        !controller!.value.isTakingPicture) {
      try {
        logger.i("Capturing image...");
        XFile picture = await controller!.takePicture();
        setState(() => imageFile = picture);
        if (mounted) _processImage(picture);
      } catch (e) {
        logger.e("Error capturing image: $e");
      }
    }
  }

  Future<void> pickImage() async {
    try {
      logger.i("Picking image from gallery...");
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => imageFile = pickedFile);
        if (mounted) _processImage(pickedFile);
      }
    } catch (e) {
      logger.e("Error picking image: $e");
    }
  }

  Future<void> _processImage(XFile image) async {
    try {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      // Directly classify the image without leaf detection
      var classificationResult = await classifyLeaf(image.path);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              plantName: classificationResult.label,
              imagePath: image.path,
              confidence: classificationResult.confidence,
            ),
          ),
        );
      }
    } catch (e) {
      logger.e("Error processing image: $e");
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  // Leaf detection code is commented out
  // Future<bool> detectLeaf(String imagePath) async {
  //   // Leaf detection code is disabled
  // }

  Future<ClassificationResult> classifyLeaf(String imagePath) async {
    try {
      logger.i("Starting leaf classification...");
      // Load and preprocess the image
      Uint8List imageBytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        logger.e("Image decoding failed.");
        return ClassificationResult.empty();
      }

      // Get input size from the model
      var inputShape = _leafClassifierInterpreter!.getInputTensor(0).shape;
      int inputHeight = inputShape[1];
      int inputWidth = inputShape[2];

      logger.i("Resizing image to ($inputWidth, $inputHeight) for classifier.");
      img.Image resizedImage =
          img.copyResize(image, width: inputWidth, height: inputHeight);

      var input = Float32List(1 * inputHeight * inputWidth * 3);
      var buffer = Float32List.view(input.buffer);
      int pixelIndex = 0;
      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          var pixel = resizedImage.getPixel(x, y);
          buffer[pixelIndex++] = (img.getRed(pixel) / 127.5) - 1.0;
          buffer[pixelIndex++] = (img.getGreen(pixel) / 127.5) - 1.0;
          buffer[pixelIndex++] = (img.getBlue(pixel) / 127.5) - 1.0;
        }
      }

      var inputTensor = input.reshape([1, inputHeight, inputWidth, 3]);

      if (_leafClassifierInterpreter == null) {
        logger.e("Leaf Classifier interpreter is not initialized.");
        return ClassificationResult.empty();
      }

      var output = List.filled(_classifierLabels.length, 0.0)
          .reshape([1, _classifierLabels.length]);

      logger.i("Running leaf classifier interpreter...");
      _leafClassifierInterpreter!.run(inputTensor, output);

      var probabilities = output[0];
      logger.i("Classification probabilities: $probabilities");

      int maxIndex = 0;
      double maxProbability = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProbability) {
          maxProbability = probabilities[i];
          maxIndex = i;
        }
      }

      String predictedLabel = _classifierLabels[maxIndex];
      double confidence = maxProbability * 100.0;

      logger.i(
          "Classification result: $predictedLabel with confidence: $confidence%");

      return ClassificationResult(
        label: predictedLabel,
        confidence: confidence,
      );
    } catch (e) {
      logger.e("Error during leaf classification: $e");
      return ClassificationResult.empty();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    // _leafDetectorInterpreter?.close(); // Commented out leaf detector interpreter
    _leafClassifierInterpreter?.close();
    super.dispose();
  }

  void _showModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Menu',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About App'),
                onTap: () {
                  Navigator.pop(context);
                  // Handle the About action here
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('About App'),
                        content: const Text(
                          'Florafolium is your ultimate plant leaf identification and classification app, designed for nature enthusiasts, gardeners, and anyone interested in plants. '
                          'Using advanced image recognition technology, Florafolium makes it easy to identify plants with ease. '
                          'Simply take a photo or upload an image, and the app will provide you with detailed information about the plant species. '
                          'It will also tell you if the plant is Edible, Medicinal, or Toxic.',
                          textAlign: TextAlign.justify, // Justify the text
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                onTap: () {
                  Navigator.pop(context);
                  // Handle language selection here
                },
              ),
              // Add more options as needed
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD5E8D4),
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 350, // Adjust height as needed
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _buildCustomHamburgerIcon(), // Custom hamburger icon
            onPressed: _showModal, // Show modal on tap
          ),
        ],
      ),
      body: Stack(
        // Use Stack to overlay loading indicator
        children: [
          SingleChildScrollView(
            child: Container(
              color: const Color(0xFFD5E8D4),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: controller?.value.isInitialized == true
                            ? CameraPreview(controller!)
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconContainer(
                          iconPath: 'assets/upload.png',
                          onPressed: pickImage,
                        ),
                        IconContainer(
                          iconPath: 'assets/startcamera.png',
                          onPressed: captureImage,
                        ),
                        IconContainer(
                          iconPath: 'assets/tips.png',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Snap Tips'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        const Text(
                                          '1. FOCUS ON A SINGLE LEAF.',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16.0),
                                          child: Text(
                                            'Take a picture of just one leaf, so the app won’t get confused by other plants around it.',
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          '2. CAPTURE IN GOOD LIGHTING.',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16.0),
                                          child: Text(
                                            'Take the photo in natural daylight to ensure clear image details.',
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          '3. CENTER THE LEAF.',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16.0),
                                          child: Text(
                                            'Place the leaf in the center of the screen, so the app can easily identify it. Make sure the whole leaf is visible.',
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        // Add more tips as needed
                                      ],
                                    ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                        child: const Text('Close'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        }),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Display loading indicator with blurred background if processing
          if (_isLoading)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Blur effect
              child: Container(
                color: Colors.black54, // Semi-transparent background
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text(
                        "Please wait...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomHamburgerIcon() {
    return Container(
      padding: const EdgeInsets.all(10.0), // Padding around the icon
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(height: 4, width: 25, color: Colors.green), // Top bar
          const SizedBox(height: 4),
          Container(height: 4, width: 25, color: Colors.green), // Middle bar
          const SizedBox(height: 4),
          Container(height: 4, width: 25, color: Colors.green), // Bottom bar
        ],
      ),
    );
  }
}

class IconContainer extends StatelessWidget {
  final String iconPath;
  final VoidCallback onPressed;

  const IconContainer(
      {super.key, required this.iconPath, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
        color: Colors.white,
      ),
      child: IconButton(
        icon: Image.asset(iconPath),
        iconSize: 50,
        onPressed: onPressed,
      ),
    );
  }
}

class ClassificationResult {
  final String label;
  final double confidence;

  ClassificationResult({
    required this.label,
    required this.confidence,
  });

  factory ClassificationResult.empty() {
    return ClassificationResult(
      label: 'Unknown',
      confidence: 0.0,
    );
  }
}
