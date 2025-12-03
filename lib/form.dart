import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Replicating Theme Colors for a standalone file ---
const Color primaryGreen = Color(0xFF00796B);       // Primary accent color
const Color primaryLight = Color(0xFF4DB6AC);       // Lighter accent
const Color backgroundLight = Color(0xFFF0F4F7);    // Background/soft screen
const Color cardWhite = Color(0xFFFFFFFF);          // Pure white for floating elements
const Color textDark = Color(0xFF212121);           // Deep black for headlines
const Color textLight = Color(0xFF757575);          // Subtle gray for body text
const Color shadowDark = Color(0xFFC5DDE8);         // Shadow color

// =================================================================
// MAIN FORM WIDGET
// =================================================================
class MedicalProfileForm extends StatefulWidget {
  const MedicalProfileForm({super.key});

  @override
  State<MedicalProfileForm> createState() => _MedicalProfileFormState();
}

class _MedicalProfileFormState extends State<MedicalProfileForm> {
  // Form controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _culturalDietController = TextEditingController();
  final TextEditingController _otherFoodVetoesController = TextEditingController();
  final TextEditingController _drug1Controller = TextEditingController();
  final TextEditingController _drug2Controller = TextEditingController();
  final TextEditingController _hba1cController = TextEditingController();
  final TextEditingController _creatinineController = TextEditingController();
  final TextEditingController _ldlController = TextEditingController();
  final TextEditingController _hdlController = TextEditingController();
  final TextEditingController _triglyceridesController = TextEditingController();

  // Form state variables
  String? _selectedSex;
  String? _selectedBodyType;
  String? _selectedActivityLevel;
  String? _selectedDietType;
  Set<String> _selectedDiseases = {};
  Set<String> _selectedAllergies = {};
  Set<String> _selectedGoals = {};
  Set<String> _drug1Restrictions = {};
  Set<String> _drug2Restrictions = {};
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper for section headers
  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: primaryGreen,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textLight,
            ),
          ),
          const Divider(height: 15, thickness: 1.5, color: primaryLight),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final profileDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicalProfile')
          .doc('current')
          .get();
      
      if (profileDoc.exists) {
        final data = profileDoc.data()!;
        setState(() {
          // Load basic info
          _ageController.text = data['age']?.toString() ?? '';
          _heightController.text = data['height']?.toString() ?? '';
          _weightController.text = data['weight']?.toString() ?? '';
          _selectedSex = data['sex'];
          _selectedBodyType = data['bodyType'];
          _selectedActivityLevel = data['activityLevel'];
          
          // Load medical data
          _selectedDiseases = Set<String>.from(data['diseases'] ?? []);
          _selectedAllergies = Set<String>.from(data['allergies'] ?? []);
          _otherFoodVetoesController.text = data['otherFoodVetoes'] ?? '';
          
          // Load medications
          final medications = data['medications'] as Map<String, dynamic>? ?? {};
          _drug1Controller.text = medications['drug1']?['name'] ?? '';
          _drug2Controller.text = medications['drug2']?['name'] ?? '';
          _drug1Restrictions = Set<String>.from(medications['drug1']?['restrictions'] ?? []);
          _drug2Restrictions = Set<String>.from(medications['drug2']?['restrictions'] ?? []);
          
          // Load diet and goals
          _selectedDietType = data['dietType'];
          _culturalDietController.text = data['culturalDiet'] ?? '';
          _selectedGoals = Set<String>.from(data['healthGoals'] ?? []);
          
          // Load lab markers
          final labMarkers = data['labMarkers'] as Map<String, dynamic>? ?? {};
          _hba1cController.text = labMarkers['hba1c']?.toString() ?? '';
          _creatinineController.text = labMarkers['creatinine']?.toString() ?? '';
          _ldlController.text = labMarkers['ldl']?.toString() ?? '';
          _hdlController.text = labMarkers['hdl']?.toString() ?? '';
          _triglyceridesController.text = labMarkers['triglycerides']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('Error loading existing data: $e');
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _culturalDietController.dispose();
    _otherFoodVetoesController.dispose();
    _drug1Controller.dispose();
    _drug2Controller.dispose();
    _hba1cController.dispose();
    _creatinineController.dispose();
    _ldlController.dispose();
    _hdlController.dispose();
    _triglyceridesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundLight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 30),
            // --- Sections based on essential_medical_profile.md ---
            _buildSectionHeader('SECTION 1: CORE PERSONAL METRICS', 'Mandatory for Calorie/Macro Planning'),
            _buildCoreMetrics(),
            const SizedBox(height: 30),
            _buildSectionHeader('SECTION 2: MEDICAL RESTRICTIONS', 'Safety Critical Constraints'),
            _buildMedicalRestrictions(),
            const SizedBox(height: 30),
            _buildSectionHeader('SECTION 3: BASELINE DIET', 'Context for AI Recommendations'),
            _buildBaselineDiet(),
            const SizedBox(height: 30),
            _buildSectionHeader('SECTION 4: HEALTH GOALS', 'Defining the Plan'),
            _buildHealthGoals(),
            const SizedBox(height: 30),
            _buildSectionHeader('SECTION 5: KEY LAB MARKERS', 'Optional - Skip if not available'),
            _buildLabMarkers(),
            const SizedBox(height: 40),
            // --- Submission Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryLight,
                  foregroundColor: cardWhite,
                  minimumSize: const Size(0, 55), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: cardWhite)
                  : const Text('Save Profile & Start Personalized Scan', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryGreen, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: primaryGreen, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Safety First',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'The information you provide is the foundation of our safe and personalized nutrition recommendations. Please be accurate.',
                  style: TextStyle(
                    fontSize: 14,
                    color: textDark.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label, 
    String hint = '', 
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryGreen, width: 2.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }

  // =================================================================
  // SECTION 1: CORE PERSONAL METRICS
  // =================================================================
  Widget _buildCoreMetrics() {
    return _buildSectionContainer(
      children: [
        _buildFormField(label: 'Age *', keyboardType: TextInputType.number, controller: _ageController),
        _buildRadioGroup(
          'Sex *', 
          ['Male', 'Female', 'Other'], 
          _selectedSex,
          (value) => setState(() => _selectedSex = value),
        ),
        Column(
          children: [
            _buildFormField(label: 'Height', hint: 'cm', keyboardType: TextInputType.number, controller: _heightController),
            _buildFormField(label: 'Weight', hint: 'kg', keyboardType: TextInputType.number, controller: _weightController),
          ],
        ),
        _buildRadioGroup('Body Type *', ['Slim', 'Average', 'Athletic', 'Overweight', 'Obese'], _selectedBodyType, (value) => setState(() => _selectedBodyType = value)),
        _buildRadioGroup('Activity Level *', [
          'Sedentary (Desk Job)', 
          'Light Active (1-3x/week)', 
          'Moderate Active (3-5x/week)', 
          'High Active (Hard daily exercise)'
        ], _selectedActivityLevel, (value) => setState(() => _selectedActivityLevel = value)),
      ],
    );
  }

  // =================================================================
  // SECTION 2: MEDICAL RESTRICTIONS
  // =================================================================
  Widget _buildMedicalRestrictions() {
    return _buildSectionContainer(
      children: [
        Text('Chronic Diseases: *', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 10),
        _buildCheckboxGroup('Diseases', [
          'Diabetes Type 1', 'Diabetes Type 2 / Prediabetes', 'Chronic Kidney Disease (CKD)', 
          'Hypertension (High Blood Pressure)', 'High Cholesterol / Heart Disease', 
          'Fatty Liver (NAFLD/NASH)', 'Gout / High Uric Acid', 
          'IBS / IBD / Chronic GI Issues', 'Hypothyroidism / PCOS / PCOD', 'None'
        ], selectedValues: _selectedDiseases),
        const Divider(height: 25),

        Text('Food Allergies & Intolerances (CRITICAL Vetoes): *', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 10),
        _buildCheckboxGroup('Allergies', [
          'Nuts', 'Dairy', 'Gluten', 'Soy', 'Shellfish / Fish', 
          'Lactose intolerance', 'FODMAP intolerance (IBS)', 'None'
        ], selectedValues: _selectedAllergies),
        _buildFormField(label: 'Other Food Vetoes', hint: 'e.g., Mushrooms, Cilantro', controller: _otherFoodVetoesController),
        const Divider(height: 25),

        Text('Current Medications & Interactions (Crucial for Safety):', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        _buildMedicationInput('Drug 1', _drug1Controller, _drug1Restrictions),
        _buildMedicationInput('Drug 2', _drug2Controller, _drug2Restrictions),
      ],
    );
  }
  
  Widget _buildMedicationInput(String label, TextEditingController controller, Set<String> restrictions) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField(label: '$label Name', hint: 'e.g., Metformin, Warfarin', controller: controller),
          _buildCheckboxGroup('Known Restriction', [
            'Avoid Grapefruit', 
            'Avoid High Vitamin K Foods (Spinach, Kale)',
          ], inline: true, selectedValues: restrictions),
        ],
      ),
    );
  }


  // =================================================================
  // SECTION 3: BASELINE DIET
  // =================================================================
  Widget _buildBaselineDiet() {
    return _buildSectionContainer(
      children: [
        _buildRadioGroup('Current Diet Type', [
          'Non-vegetarian', 'Eggetarian', 'Vegetarian', 'Vegan', 
          'Keto', 'Low-carb',
        ], _selectedDietType, (value) => setState(() => _selectedDietType = value)),
        _buildFormField(label: 'Cultural Dietary Preference', hint: 'e.g., South Indian, Mediterranean, Halal', controller: _culturalDietController),
      ],
    );
  }

  // =================================================================
  // SECTION 4: HEALTH GOALS
  // =================================================================
  Widget _buildHealthGoals() {
    return _buildSectionContainer(
      children: [
        Text('What is your primary goal? *', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 10),
        _buildCheckboxGroup('Goals', [
          'Weight loss (Primary Focus)', 
          'Weight gain / Muscle building', 
          'Diabetes control / Blood Sugar Balance', 
          'PCOS Management', 
          'Lower Cholesterol / Blood Pressure',
          'Improve Digestive Health (Reduce bloating/gas)', 
          'Improve Energy / Reduce Fatigue',
          'Thyroid Balance',
        ], selectedValues: _selectedGoals),
      ],
    );
  }

  // =================================================================
  // SECTION 5: KEY LAB MARKERS
  // =================================================================
  Widget _buildLabMarkers() {
    return _buildSectionContainer(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These lab values are optional but help provide more accurate recommendations.',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _buildFormField(label: 'Recent HbA1c (Optional)', hint: '% - For Diabetes', keyboardType: TextInputType.number, controller: _hba1cController),
        _buildFormField(label: 'Creatinine/eGFR (Optional)', hint: 'For Kidney/Gout', keyboardType: TextInputType.number, controller: _creatinineController),
        _buildFormField(label: 'LDL Cholesterol (Optional)', hint: 'mg/dL', keyboardType: TextInputType.number, controller: _ldlController),
        _buildFormField(label: 'HDL Cholesterol (Optional)', hint: 'mg/dL', keyboardType: TextInputType.number, controller: _hdlController),
        _buildFormField(label: 'Triglycerides (Optional)', hint: 'mg/dL', keyboardType: TextInputType.number, controller: _triglyceridesController),
      ],
    );
  }

  // =================================================================
  // COMMON UI TEMPLATES
  // =================================================================

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCheckboxGroup(String groupName, List<String> options, {bool isRadio = false, bool inline = false, Set<String>? selectedValues}) {
    selectedValues ??= <String>{};
    
    if (inline) {
       return Wrap(
        spacing: 0,
        runSpacing: 0,
        children: options.map((option) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selectedValues!.contains(option),
              onChanged: (bool? newValue) {
                setState(() {
                  if (newValue == true) {
                    selectedValues!.add(option);
                  } else {
                    selectedValues!.remove(option);
                  }
                });
              },
              activeColor: primaryGreen,
            ),
            Text(option, style: const TextStyle(fontSize: 14, color: textDark)),
            const SizedBox(width: 10),
          ],
        )).toList(),
      );
    }

    return Column(
      children: options.map((option) => CheckboxListTile(
        title: Text(option, style: TextStyle(color: textDark, fontSize: 15)),
        value: selectedValues!.contains(option),
        onChanged: (bool? newValue) {
          setState(() {
            if (newValue == true) {
              selectedValues!.add(option);
            } else {
              selectedValues!.remove(option);
            }
          });
        },
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: isRadio ? primaryLight : primaryGreen,
        controlAffinity: ListTileControlAffinity.leading,
      )).toList(),
    );
  }

  Widget _buildRadioGroup(String groupName, List<String> options, String? currentValue, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
          child: Text(
            groupName,
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: options.map((option) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () => onChanged(option),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentValue == option ? primaryGreen : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: currentValue == option ? primaryGreen : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        color: currentValue == option ? cardWhite : textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
  
  Future<void> _saveProfile() async {
    // Mandatory field validation
    if (_ageController.text.isEmpty) {
      _showErrorDialog('Age is required');
      return;
    }
    if (_selectedSex == null) {
      _showErrorDialog('Sex is required');
      return;
    }
    if (_selectedBodyType == null) {
      _showErrorDialog('Body Type is required');
      return;
    }
    if (_selectedActivityLevel == null) {
      _showErrorDialog('Activity Level is required');
      return;
    }
    if (_selectedDiseases.isEmpty) {
      _showErrorDialog('Please select chronic diseases (or None if applicable)');
      return;
    }
    if (_selectedAllergies.isEmpty) {
      _showErrorDialog('Please select food allergies (or None if applicable)');
      return;
    }
    if (_selectedGoals.isEmpty) {
      _showErrorDialog('Please select at least one health goal');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorDialog('User not logged in');
        return;
      }

      // Prepare data for Firestore
      final profileData = {
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'profileComplete': true,
        
        // Core metrics
        'age': int.tryParse(_ageController.text) ?? 0,
        'sex': _selectedSex,
        'height': double.tryParse(_heightController.text) ?? 0,
        'weight': double.tryParse(_weightController.text) ?? 0,
        'bodyType': _selectedBodyType,
        'activityLevel': _selectedActivityLevel,
        
        // Medical restrictions
        'diseases': _selectedDiseases.toList(),
        'allergies': _selectedAllergies.toList(),
        'otherFoodVetoes': _otherFoodVetoesController.text.trim(),
        'medications': {
          'drug1': {
            'name': _drug1Controller.text.trim(),
            'restrictions': _drug1Restrictions.toList(),
          },
          'drug2': {
            'name': _drug2Controller.text.trim(),
            'restrictions': _drug2Restrictions.toList(),
          },
        },
        
        // Diet and goals
        'dietType': _selectedDietType,
        'culturalDiet': _culturalDietController.text.trim(),
        'healthGoals': _selectedGoals.toList(),
        
        // Lab markers
        'labMarkers': {
          'hba1c': double.tryParse(_hba1cController.text) ?? 0,
          'creatinine': double.tryParse(_creatinineController.text) ?? 0,
          'ldl': double.tryParse(_ldlController.text) ?? 0,
          'hdl': double.tryParse(_hdlController.text) ?? 0,
          'triglycerides': double.tryParse(_triglyceridesController.text) ?? 0,
        },
      };

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicalProfile')
          .doc('current')
          .set(profileData, SetOptions(merge: true));

      // Also update user document to mark profile as complete
      await _firestore.collection('users').doc(user.uid).update({
        'profileComplete': true,
        'lastProfileUpdate': FieldValue.serverTimestamp(),
      });

      _showSubmissionConfirmation(context);
    } catch (e) {
      _showErrorDialog('Failed to save profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: primaryGreen)),
          ),
        ],
      ),
    );
  }

  void _showSubmissionConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: primaryGreen, size: 30),
              const SizedBox(width: 10),
              const Text('Profile Saved!'),
            ],
          ),
          content: const Text(
            'Your essential medical profile has been successfully saved to our secure database. You can now use the instant food scan feature safely.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close form
              },
              child: const Text('OK', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}