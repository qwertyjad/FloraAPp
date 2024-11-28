import 'dart:io';
import 'package:flutter/material.dart';
import 'plant_info.dart';
import 'dart:developer'; // Import the logger

class ResultScreen extends StatefulWidget {
  final String plantName;
  final String imagePath;
  final double confidence;

  const ResultScreen({
    super.key,
    required this.plantName,
    required this.imagePath,
    required this.confidence,
  });

  @override
  ResultScreenState createState() => ResultScreenState();
}

class ResultScreenState extends State<ResultScreen> {
  String currentLanguage = 'en';

  void toggleLanguage() {
    setState(() {
      currentLanguage = currentLanguage == 'en' ? 'tl' : 'en';
      log('Language toggled to $currentLanguage');
    });
  }

  @override
  void initState() {
    super.initState();
    log('Initializing ResultScreen with the following data:');
    log('Plant Name (original): ${widget.plantName}');
    log('Plant Name (normalized): ${widget.plantName.toLowerCase()}');
    log('Image Path: ${widget.imagePath}');
    log('Confidence: ${widget.confidence}');
  }

  Map<String, dynamic> _getDefaultPlantInfo() {
    log('Fetching default plant information as fallback.');
    return {
      'plantType': 'Unknown',
      'scientificName': {'en': 'N/A', 'tl': 'N/A'},
      'CommonName': {'en': 'N/A', 'tl': 'N/A'},
      'description': {
        'en': 'No information is available for this plant.',
        'tl': 'Walang impormasyon tungkol sa halamang ito.'
      },
      'healthBenefits': {
        'en': 'No health benefits available.',
        'tl': 'Walang mga benepisyo sa kalusugan na magagamit.'
      },
      'procedure': {
        'en': 'No specific procedure available.',
        'tl': 'Walang tiyak na pamamaraan na magagamit.'
      },
      'medicinalBenefits': {
        'en': 'No medicinal benefits available.',
        'tl': 'Walang benepisyo sa medisina na magagamit.'
      },
      'precautions': {
        'en': 'No precautions available.',
        'tl': 'Walang mga pag-iingat na magagamit.'
      },
      'hazards': {
        'en': 'No hazards available.',
        'tl': 'Walang mga panganib na magagamit.'
      },
      'symptoms': {
        'en': 'No symptoms available.',
        'tl': 'Walang mga sintomas na magagamit.'
      }
    };
  }

  String getLocalizedValue(dynamic value) {
    if (value is String) {
      return value;
    } else if (value is Map) {
      return value[currentLanguage] ?? 'N/A';
    } else {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedPlantName = widget.plantName.toLowerCase().trim();
    log('Normalized Plant Name for lookup: $normalizedPlantName');

    final plantInfo = PlantInfoData.plantInfoMap[normalizedPlantName] ??
        _getDefaultPlantInfo();
    if (plantInfo == _getDefaultPlantInfo()) {
      log('No data found for plant "$normalizedPlantName". Using default information.');
    } else {
      log('Data fetched successfully for plant "$normalizedPlantName".');
    }

    log('Plant Info: $plantInfo');

    final plantType = plantInfo['plantType'] ?? 'Unknown';
    log('Plant Type: $plantType');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD5E8D4),
        elevation: 0,
        title: const Text(
          'Result',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            log('Navigating back from ResultScreen.');
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              currentLanguage == 'en' ? Icons.language : Icons.translate,
              color: Colors.black,
            ),
            tooltip: 'Toggle Language',
            onPressed: toggleLanguage,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (File(widget.imagePath).existsSync())
              Image.file(
                File(widget.imagePath),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/placeholder.png',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Image not found',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              '${widget.plantName} (${widget.confidence.toStringAsFixed(2)}%)',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Scrollbar(
                  thickness: 5,
                  radius: const Radius.circular(10),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Characteristics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Plant type:', plantType),
                        _buildInfoRow(
                          'Scientific Name:',
                          getLocalizedValue(plantInfo['scientificName']),
                        ),
                        _buildInfoRow(
                          'Common Name:',
                          getLocalizedValue(plantInfo['CommonName']),
                        ),
                        const SizedBox(height: 10),
                        _buildExpandableSection(
                          'Description:',
                          getLocalizedValue(plantInfo['description']),
                        ),
                        if (plantType == 'Edible') ...[
                          _buildExpandableSection(
                            'Health Benefits:',
                            getLocalizedValue(plantInfo['healthBenefits']),
                          ),
                          _buildExpandableSection(
                            'Procedure:',
                            getLocalizedValue(plantInfo['procedure']),
                          ),
                        ],
                        if (plantType == 'Medicinal') ...[
                          _buildExpandableSection(
                            'Medicinal Benefits:',
                            getLocalizedValue(plantInfo['medicinalBenefits']),
                          ),
                          _buildExpandableSection(
                            'Precautions:',
                            getLocalizedValue(plantInfo['precautions']),
                          ),
                        ],
                        if (plantType == 'Toxic') ...[
                          _buildExpandableSection(
                            'Hazards:',
                            getLocalizedValue(plantInfo['hazards']),
                          ),
                          _buildExpandableSection(
                            'Symptoms:',
                            getLocalizedValue(plantInfo['symptoms']),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    log('Building info row: $label - $value');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              value ?? 'Unknown',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection(String title, String? content) {
    bool isExpanded = false;
    log('Building expandable section: $title');

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => isExpanded = !isExpanded);
                log('Toggled expansion for: $title. Expanded: $isExpanded');
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  content ?? 'No information available.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        );
      },
    );
  }
}
