import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/auth_service.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _hotelNameController = TextEditingController();
  final _hotelPriceController = TextEditingController();
  
  final List<Map<String, dynamic>> _places = [];
  final _placeNameController = TextEditingController();
  final _placePriceController = TextEditingController();

  PlatformFile? _pickedHotelFile;
  PlatformFile? _pickedPlaceFile;
  bool _isUploading = false;

  static const _coral = Color(0xFFFF6B6B);

  double get _totalBudget {
    double hotelPrice = double.tryParse(_hotelPriceController.text) ?? 0;
    double placesPrice = _places.fold(0, (sum, item) => sum + (item['price'] as double));
    return hotelPrice + placesPrice;
  }

  Future<void> _pickHotelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc'],
    );
    if (result != null) {
      setState(() => _pickedHotelFile = result.files.first);
    }
  }

  Future<void> _pickPlaceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc'],
    );
    if (result != null) {
      setState(() => _pickedPlaceFile = result.files.first);
    }
  }

  Future<String?> _uploadFile(PlatformFile pickedFile, String userId, String subFolder) async {
    if (pickedFile.path == null) return null;
    
    final file = File(pickedFile.path!);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
    final destination = 'users/$userId/$subFolder/$fileName';

    try {
      final ref = FirebaseStorage.instance.ref(destination);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  void _addPlace() {
    if (_placeNameController.text.isNotEmpty) {
      setState(() {
        _places.add({
          'name': _placeNameController.text,
          'price': double.tryParse(_placePriceController.text) ?? 0.0,
          'tempFile': _pickedPlaceFile, // Temporarily store the file object
        });
        _placeNameController.clear();
        _placePriceController.clear();
        _pickedPlaceFile = null;
      });
    }
  }

  Future<void> _savePlan() async {
    if (_formKey.currentState!.validate()) {
      final user = _authService.currentUser;
      if (user == null) return;

      setState(() => _isUploading = true);

      try {
        // Upload Hotel Doc
        String? hotelFileUrl;
        if (_pickedHotelFile != null) {
          hotelFileUrl = await _uploadFile(_pickedHotelHotelFile!, user.uid, 'hotel_documents');
        }

        // Upload Place Docs
        List<Map<String, dynamic>> finalPlaces = [];
        for (var place in _places) {
          String? placeFileUrl;
          String? fileName;
          if (place['tempFile'] != null) {
            PlatformFile pf = place['tempFile'];
            placeFileUrl = await _uploadFile(pf, user.uid, 'place_documents');
            fileName = pf.name;
          }
          
          finalPlaces.add({
            'name': place['name'],
            'price': place['price'],
            'documentUrl': placeFileUrl,
            'documentName': fileName,
          });
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('trips')
            .add({
          'city': _cityController.text,
          'country': _countryController.text,
          'hotelName': _hotelNameController.text,
          'hotelPrice': double.tryParse(_hotelPriceController.text) ?? 0,
          'hotelDocumentUrl': hotelFileUrl,
          'hotelDocumentName': _pickedHotelFile?.name,
          'places': finalPlaces,
          'totalBudget': _totalBudget,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip plan and documents saved!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Trip'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _coral.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_totalBudget.toStringAsFixed(0)} units',
                  style: const TextStyle(color: _coral, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Destination', textColor),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(_cityController, 'City', Icons.location_city),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(_countryController, 'Country', Icons.public),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Accommodation', textColor),
                  const SizedBox(height: 12),
                  _buildTextField(_hotelNameController, 'Hotel Name', Icons.hotel),
                  const SizedBox(height: 12),
                  _buildTextField(_hotelPriceController, 'Hotel Price (unit)', Icons.payments, isNumber: true),
                  const SizedBox(height: 12),
                  
                  // Hotel Document Upload
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _coral.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, color: _coral),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pickedHotelFile?.name ?? 'No hotel document selected',
                            style: TextStyle(color: textColor, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: _pickHotelFile,
                          child: const Text('Select File', style: TextStyle(color: _coral)),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Places to Visit', textColor),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_placeNameController, 'Place Name', Icons.place)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField(_placePriceController, 'Price', Icons.attach_money, isNumber: true)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _pickedPlaceFile?.name ?? 'Optional document',
                                style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: _pickPlaceFile,
                              icon: const Icon(Icons.attach_file, color: _coral, size: 20),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addPlace,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _coral,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Add'),
                            )
                          ],
                        ),
                        if (_places.isNotEmpty) ...[
                          const Divider(height: 24),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _places.length,
                            itemBuilder: (context, index) {
                              final place = _places[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(place['name'], style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  place['tempFile'] != null 
                                    ? '📎 ${place['tempFile'].name}' 
                                    : 'No document',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${place['price']} units', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                      onPressed: () => setState(() => _places.removeAt(index)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _savePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isUploading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Trip Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _coral),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) {
        if (label == 'Hotel Name' || label == 'Hotel Price (unit)') return null; // Make hotel optional if you want
        return value == null || value.isEmpty ? 'Required' : null;
      },
    );
  }

  // Fixing the variable name error in _savePlan
  PlatformFile? get _pickedHotelHotelFile => _pickedHotelFile;
}
