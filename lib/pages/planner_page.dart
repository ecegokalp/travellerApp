import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/gemini_service.dart';

class PlannerPage extends StatefulWidget {
  final Map<String, dynamic>? existingTrip;
  final String? tripId;

  const PlannerPage({super.key, this.existingTrip, this.tripId});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  final AuthService _authService = AuthService();
  final GeminiService _geminiService = GeminiService();
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
  PlatformFile? _pickedFlightFile;
  bool _isUploading = false;

  DateTime? _startDate;
  DateTime? _endDate;
  String _hotelCurrency = 'TRY';
  String _placeCurrency = 'TRY';
  String _budgetLimitCurrency = 'TRY';
  final _budgetLimitController = TextEditingController();
  String _loadingMessage = 'AI is processing document...';
  String? _existingHotelFileName;
  String? _existingFlightFileName;
  String? _existingHotelFileUrl;
  String? _existingFlightFileUrl;
  final _currencyService = CurrencyService();
  Map<String, double>? _rates;

  // Budget categories
  final _flightController = TextEditingController();
  String _flightCurrency = 'TRY';
  final _foodController = TextEditingController();
  String _foodCurrency = 'TRY';
  final _transportController = TextEditingController();
  String _transportCurrency = 'TRY';
  final _otherController = TextEditingController();
  String _otherCurrency = 'TRY';

  static const _coral = Color(0xFFFF6B6B);

  bool get _isEditing => widget.existingTrip != null;

  double get _totalBudget {
    double hotelPrice = double.tryParse(_hotelPriceController.text) ?? 0;
    double placesPrice = _places.fold(0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0));
    double flight = double.tryParse(_flightController.text) ?? 0;
    double food = double.tryParse(_foodController.text) ?? 0;
    double transport = double.tryParse(_transportController.text) ?? 0;
    double other = double.tryParse(_otherController.text) ?? 0;
    return hotelPrice + placesPrice + flight + food + transport + other;
  }

  double get _totalBudgetTRY {
    if (_rates == null) return _totalBudget;
    double hotel = _currencyService.convertToTRY(
      double.tryParse(_hotelPriceController.text) ?? 0, _hotelCurrency, _rates!);
    double places = _places.fold(0.0, (sum, p) =>
      sum + _currencyService.convertToTRY((p['price'] as num?)?.toDouble() ?? 0, p['currency'] ?? 'TRY', _rates!));
    double flight = _currencyService.convertToTRY(double.tryParse(_flightController.text) ?? 0, _flightCurrency, _rates!);
    double food = _currencyService.convertToTRY(double.tryParse(_foodController.text) ?? 0, _foodCurrency, _rates!);
    double transport = _currencyService.convertToTRY(double.tryParse(_transportController.text) ?? 0, _transportCurrency, _rates!);
    double other = _currencyService.convertToTRY(double.tryParse(_otherController.text) ?? 0, _otherCurrency, _rates!);
    return hotel + places + flight + food + transport + other;
  }

  double get _budgetLimitTRY {
    final raw = double.tryParse(_budgetLimitController.text) ?? 0;
    if (_rates == null) return raw;
    return _currencyService.convertToTRY(raw, _budgetLimitCurrency, _rates!);
  }

  @override
  void initState() {
    super.initState();
    _currencyService.getRatesToTRY().then((r) { if (mounted) setState(() => _rates = r); });
    if (_isEditing) _loadExistingData();
  }

  void _loadExistingData() {
    final d = widget.existingTrip!;
    _cityController.text = d['city'] ?? '';
    _countryController.text = d['country'] ?? '';
    _hotelNameController.text = d['hotelName'] ?? '';
    _hotelPriceController.text = (d['hotelPrice'] ?? 0).toString();
    _hotelCurrency = d['hotelCurrency'] ?? 'TRY';
    _existingHotelFileName = d['hotelDocumentName'];
    _existingFlightFileName = d['flightDocumentName'];
    _existingHotelFileUrl = d['hotelDocumentUrl'];
    _existingFlightFileUrl = d['flightDocumentUrl'];
    if (d['startDate'] != null) _startDate = (d['startDate'] as Timestamp).toDate();
    if (d['endDate'] != null) _endDate = (d['endDate'] as Timestamp).toDate();
    if (d['budgetLimit'] != null) _budgetLimitController.text = d['budgetLimit'].toString();
    _budgetLimitCurrency = d['budgetLimitCurrency'] ?? 'TRY';
    final cats = d['budgetCategories'] as Map<String, dynamic>?;
    if (cats != null) {
      if (cats['Flight'] != null) { _flightController.text = (cats['Flight']['amount'] ?? 0).toString(); _flightCurrency = cats['Flight']['currency'] ?? 'TRY'; }
      if (cats['Food'] != null) { _foodController.text = (cats['Food']['amount'] ?? 0).toString(); _foodCurrency = cats['Food']['currency'] ?? 'TRY'; }
      if (cats['Transport'] != null) { _transportController.text = (cats['Transport']['amount'] ?? 0).toString(); _transportCurrency = cats['Transport']['currency'] ?? 'TRY'; }
      if (cats['Other'] != null) { _otherController.text = (cats['Other']['amount'] ?? 0).toString(); _otherCurrency = cats['Other']['currency'] ?? 'TRY'; }
    }
    for (var p in (d['places'] ?? [])) {
      _places.add({'name': p['name'], 'price': (p['price'] as num?)?.toDouble() ?? 0, 'currency': p['currency'] ?? 'TRY', 'documentUrl': p['documentUrl'], 'documentName': p['documentName']});
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _startDate!.isAfter(_endDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _endDate!.isBefore(_startDate!)) {
            _startDate = null;
          }
        }
      });
    }
  }

  Future<void> _pickHotelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null) {
      setState(() => _pickedHotelFile = result.files.first);
      _processDocumentWithAI(result.files.first, type: 'hotel');
    }
  }

  Future<void> _pickFlightFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null) {
      setState(() => _pickedFlightFile = result.files.first);
      _processDocumentWithAI(result.files.first, type: 'flight');
    }
  }

  Future<void> _pickPlaceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null) {
      setState(() => _pickedPlaceFile = result.files.first);
      _processDocumentWithAI(result.files.first, type: 'place');
    }
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    String dateStr = dateValue.toString();
    try {
      // Standart format: 2024-05-15
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        // Alternatif: 15.05.2024 veya 15/05/2024
        List<String> parts = dateStr.split(RegExp(r'[\.\/-]'));
        if (parts.length == 3) {
          if (parts[0].length == 4) { // YYYY-MM-DD
            return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else { // DD-MM-YYYY
            return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _processDocumentWithAI(PlatformFile pickedFile, {required String type}) async {
    if (pickedFile.path == null) return;

    setState(() {
      _isUploading = true;
      _loadingMessage = 'AI is analyzing your ${type == 'place' ? 'booking' : type}...';
    });
    
    try {
      final file = File(pickedFile.path!);
      final data = await _geminiService.processDocument(file);

      if (data != null && mounted) {
        setState(() {
          // General Info
          if (data['city'] != null && _cityController.text.isEmpty) {
            _cityController.text = data['city'].toString();
          }
          if (data['country'] != null && _countryController.text.isEmpty) {
            _countryController.text = data['country'].toString();
          }

          if (type == 'place') {
            if (data['name'] != null) _placeNameController.text = data['name'].toString();
            if (data['price'] != null) _placePriceController.text = data['price'].toString();
            if (data['currency'] != null) {
              String cur = data['currency'].toString().toUpperCase();
              if (CurrencyService.supportedCurrencies.contains(cur)) {
                _placeCurrency = cur;
              }
            }
          } else if (type == 'hotel') {
            if (data['name'] != null) _hotelNameController.text = data['name'].toString();
            if (data['price'] != null) _hotelPriceController.text = data['price'].toString();
            if (data['currency'] != null) {
              String cur = data['currency'].toString().toUpperCase();
              if (CurrencyService.supportedCurrencies.contains(cur)) {
                _hotelCurrency = cur;
              }
            }
          } else if (type == 'flight') {
            if (data['price'] != null) _flightController.text = data['price'].toString();
            if (data['currency'] != null) {
              String cur = data['currency'].toString().toUpperCase();
              if (CurrencyService.supportedCurrencies.contains(cur)) {
                _flightCurrency = cur;
              }
            }
          }

          // Dates logic: Expand the trip range based on document dates
          DateTime? aiStart = _parseDate(data['startDate']);
          DateTime? aiEnd = _parseDate(data['endDate']);

          if (aiStart != null) {
            if (_startDate == null || aiStart.isBefore(_startDate!)) _startDate = aiStart;
            if (_endDate == null || aiStart.isAfter(_endDate!)) _endDate = aiStart;
          }
          if (aiEnd != null) {
            if (_startDate == null || aiEnd.isBefore(_startDate!)) _startDate = aiEnd;
            if (_endDate == null || aiEnd.isAfter(_endDate!)) _endDate = aiEnd;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI extracted ${type == 'flight' ? 'flight' : type} details and dates!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI could not extract data from this document. Please enter details manually.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AI Processing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Processing failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
          'currency': _placeCurrency,
          'tempFile': _pickedPlaceFile,
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

      setState(() {
        _isUploading = true;
        _loadingMessage = 'Saving your trip plan...';
      });

      try {
        // Upload Hotel Doc
        String? hotelFileUrl = _existingHotelFileUrl;
        if (_pickedHotelFile != null) {
          hotelFileUrl = await _uploadFile(_pickedHotelFile!, user.uid, 'hotel_documents');
        }

        // Upload Flight Doc
        String? flightFileUrl = _existingFlightFileUrl;
        if (_pickedFlightFile != null) {
          flightFileUrl = await _uploadFile(_pickedFlightFile!, user.uid, 'flight_documents');
        }

        // Upload Place Docs
        List<Map<String, dynamic>> finalPlaces = [];
        for (var place in _places) {
          String? placeFileUrl = place['documentUrl'];
          String? fileName = place['documentName'];
          
          if (place['tempFile'] != null) {
            PlatformFile pf = place['tempFile'];
            placeFileUrl = await _uploadFile(pf, user.uid, 'place_documents');
            fileName = pf.name;
          }
          
          finalPlaces.add({
            'name': place['name'],
            'price': place['price'],
            'currency': place['currency'] ?? 'TRY',
            'documentUrl': placeFileUrl,
            'documentName': fileName,
          });
        }

        final tripData = {
          'city': _cityController.text,
          'country': _countryController.text,
          'hotelName': _hotelNameController.text,
          'hotelPrice': double.tryParse(_hotelPriceController.text) ?? 0,
          'hotelCurrency': _hotelCurrency,
          'hotelDocumentUrl': hotelFileUrl,
          'hotelDocumentName': _pickedHotelFile?.name ?? _existingHotelFileName,
          'flightDocumentUrl': flightFileUrl,
          'flightDocumentName': _pickedFlightFile?.name ?? _existingFlightFileName,
          'places': finalPlaces,
          'totalBudget': _totalBudget,
          'totalBudgetTRY': _totalBudgetTRY,
          'budgetLimit': double.tryParse(_budgetLimitController.text),
          'budgetLimitCurrency': _budgetLimitCurrency,
          'budgetCategories': {
            'Flight': {'amount': double.tryParse(_flightController.text) ?? 0, 'currency': _flightCurrency},
            'Food': {'amount': double.tryParse(_foodController.text) ?? 0, 'currency': _foodCurrency},
            'Transport': {'amount': double.tryParse(_transportController.text) ?? 0, 'currency': _transportCurrency},
            'Other': {'amount': double.tryParse(_otherController.text) ?? 0, 'currency': _otherCurrency},
          },
          'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
          'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        };

        final tripsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('trips');

        if (_isEditing && widget.tripId != null) {
          tripData['updatedAt'] = FieldValue.serverTimestamp();
          await tripsRef.doc(widget.tripId).update(tripData);
        } else {
          tripData['createdAt'] = FieldValue.serverTimestamp();
          await tripsRef.add(tripData);
        }

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
                  '${_totalBudgetTRY.toStringAsFixed(0)} ₺',
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

                  // Travel Dates
                  _buildSectionTitle('Travel Dates', textColor),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _dateChip('Start', _startDate, true, cardColor, textColor)),
                    const SizedBox(width: 12),
                    Expanded(child: _dateChip('End', _endDate, false, cardColor, textColor)),
                  ]),
                  if (_startDate != null && _endDate != null)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text('${_endDate!.difference(_startDate!).inDays} days', style: TextStyle(fontSize: 13, color: _coral, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Flight Details', textColor),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight_takeoff, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pickedFlightFile?.name ?? _existingFlightFileName ?? 'Upload flight ticket to auto-fill',
                            style: TextStyle(color: textColor, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: _pickFlightFile,
                          child: const Text('Select Ticket', style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Accommodation', textColor),
                  const SizedBox(height: 12),
                  _buildTextField(_hotelNameController, 'Hotel Name', Icons.hotel),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildTextField(_hotelPriceController, 'Hotel Price', Icons.payments, isNumber: true)),
                    const SizedBox(width: 8),
                    _currencyDropdown(_hotelCurrency, (v) => setState(() => _hotelCurrency = v)),
                  ]),
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
                            _pickedHotelFile?.name ?? _existingHotelFileName ?? 'No hotel document selected',
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
                            const SizedBox(width: 8),
                            _currencyDropdown(_placeCurrency, (v) => setState(() => _placeCurrency = v)),
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
                                    : (place['documentName'] != null ? '📎 ${place['documentName']}' : 'No document'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${CurrencyService.symbol(place['currency'] ?? 'TRY')}${(place['price'] as num).toStringAsFixed(0)}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 24),

                  // Budget Limit
                  _buildSectionTitle('Budget Limit', textColor),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildTextField(_budgetLimitController, 'Max Budget', Icons.account_balance_wallet, isNumber: true)),
                    const SizedBox(width: 8),
                    _currencyDropdown(_budgetLimitCurrency, (v) => setState(() => _budgetLimitCurrency = v)),
                  ]),
                  const SizedBox(height: 16),
                  _budgetCatRow('Flight', Icons.flight_rounded, _flightController, _flightCurrency, (v) => setState(() => _flightCurrency = v), textColor),
                  _budgetCatRow('Food', Icons.restaurant_rounded, _foodController, _foodCurrency, (v) => setState(() => _foodCurrency = v), textColor),
                  _budgetCatRow('Transport', Icons.directions_bus_rounded, _transportController, _transportCurrency, (v) => setState(() => _transportCurrency = v), textColor),
                  _budgetCatRow('Other', Icons.more_horiz_rounded, _otherController, _otherCurrency, (v) => setState(() => _otherCurrency = v), textColor),

                  if (_budgetLimitTRY > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_totalBudgetTRY / _budgetLimitTRY).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        color: _totalBudgetTRY / _budgetLimitTRY > 0.9 ? Colors.red : _coral,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${_totalBudgetTRY.toStringAsFixed(0)} / ${_budgetLimitTRY.toStringAsFixed(0)} ₺', style: TextStyle(fontSize: 12, color: textColor)),
                  ],

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
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _coral),
                    const SizedBox(height: 16),
                    Text(_loadingMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _budgetCatRow(String label, IconData icon, TextEditingController controller, String currency, ValueChanged<String> onCurrencyChanged, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: _coral),
        const SizedBox(width: 6),
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: textColor))),
        const SizedBox(width: 8),
        Expanded(child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '0',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
        )),
        const SizedBox(width: 6),
        _currencyDropdown(currency, onCurrencyChanged),
      ]),
    );
  }

  Widget _dateChip(String label, DateTime? date, bool isStart, Color cardColor, Color textColor) {
    return GestureDetector(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _coral.withAlpha(60))),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 16, color: _coral),
          const SizedBox(width: 8),
          Text('$label: ${_formatDate(date)}', style: TextStyle(fontSize: 13, color: textColor)),
        ]),
      ),
    );
  }

  Widget _currencyDropdown(String value, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(border: Border.all(color: _coral.withAlpha(60)), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: CurrencyService.supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
