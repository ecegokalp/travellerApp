import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';

class PlannerPage extends StatefulWidget {
  final Map<String, dynamic>? existingTrip;
  final String? tripId;

  const PlannerPage({super.key, this.existingTrip, this.tripId});

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
  PlatformFile? _pickedFlightFile;
  bool _isUploading = false;
  bool _dirty = false;

  DateTime? _startDate;
  DateTime? _endDate;
  String _hotelCurrency = 'TRY';
  DateTime? _hotelCheckIn;
  DateTime? _hotelCheckOut;
  String? _hotelEventId;
  String _placeCurrency = 'TRY';
  String _budgetLimitCurrency = 'TRY';
  final _budgetLimitController = TextEditingController();
  String _loadingMessage = 'AI is processing document...';
  String? _existingHotelFileName;
  String? _existingFlightFileName;
  String? _existingHotelFileUrl;
  String? _existingFlightFileUrl;
  String? _existingHotelDocId;
  String? _existingFlightDocId;
  final _currencyService = CurrencyService();
  Map<String, double>? _rates;

  // Checklist
  final List<Map<String, dynamic>> _checklist = [];
  final _checklistController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final NotificationService _notificationService = NotificationService();
  bool _checklistLoading = false;

  // Day-by-day itinerary
  final List<Map<String, dynamic>> _itinerary = [];
  bool _itineraryLoading = false;

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
    double placesPrice = _places.fold(0.0, (total, item) => total + ((item['price'] as num?)?.toDouble() ?? 0));
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
    double places = _places.fold(0.0, (total, p) =>
      total + _currencyService.convertToTRY((p['price'] as num?)?.toDouble() ?? 0, p['currency'] ?? 'TRY', _rates!));
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

  bool get _hotelDatesOutOfRange {
    if (_startDate == null || _endDate == null || _hotelCheckIn == null || _hotelCheckOut == null) return false;
    return _hotelCheckIn!.isBefore(_startDate!) || _hotelCheckOut!.isAfter(_endDate!);
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
    if (d['hotelCheckIn'] != null) _hotelCheckIn = (d['hotelCheckIn'] as Timestamp).toDate();
    if (d['hotelCheckOut'] != null) _hotelCheckOut = (d['hotelCheckOut'] as Timestamp).toDate();
    _hotelEventId = d['hotelEventId'];
    _existingHotelFileName = d['hotelDocumentName'];
    _existingFlightFileName = d['flightDocumentName'];
    _existingHotelFileUrl = d['hotelDocumentUrl'];
    _existingFlightFileUrl = d['flightDocumentUrl'];
    _existingHotelDocId = d['hotelDocumentId'];
    _existingFlightDocId = d['flightDocumentId'];
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
    for (var item in (d['checklist'] ?? [])) {
      _checklist.add({'text': item['text'] ?? '', 'done': item['done'] ?? false});
    }
    for (var day in (d['itinerary'] ?? [])) {
      _itinerary.add({
        'day': day['day'] ?? 1,
        'title': day['title'] ?? '',
        'activities': List<Map<String, dynamic>>.from((day['activities'] ?? []).map((a) => {
          'time': a['time'] ?? '',
          'activity': a['activity'] ?? '',
          'description': a['description'] ?? '',
        })),
      });
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
        _dirty = true;
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

  Future<void> _pickHotelDate(bool isCheckIn) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isCheckIn ? _hotelCheckIn : _hotelCheckOut) ?? _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (picked != null) {
      setState(() {
        _dirty = true;
        if (isCheckIn) {
          _hotelCheckIn = picked;
          if (_hotelCheckOut != null && _hotelCheckIn!.isAfter(_hotelCheckOut!)) _hotelCheckOut = null;
        } else {
          _hotelCheckOut = picked;
          if (_hotelCheckIn != null && _hotelCheckOut!.isBefore(_hotelCheckIn!)) _hotelCheckIn = null;
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
    }
  }

  Future<void> _pickFlightFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null) {
      setState(() => _pickedFlightFile = result.files.first);
    }
  }

  Future<void> _pickPlaceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null) {
      setState(() => _pickedPlaceFile = result.files.first);
    }
  }

  Future<String> _syncToPersonalDocuments(String userId, String fileName, String url, int size) async {
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('personal_documents')
        .add({
      'name': fileName,
      'url': url,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'general',
      'size': size,
    });
    return docRef.id;
  }

  Future<void> _processDocumentForCalendar(File file, String fileName, String docId, String uid) async {
    try {
      final extracted = await _geminiService.processDocument(file);
      debugPrint('Gemini extracted (planner): $extracted');
      if (extracted == null) return;

      String? str(dynamic v) => v is String ? v : v is List ? v.firstOrNull?.toString() : v?.toString();
      final name = str(extracted['name']) ?? fileName;
      final city = str(extracted['city']);
      final country = str(extracted['country']);
      final startDateStr = str(extracted['startDate']);
      final endDateStr = str(extracted['endDate']);

      String eventType = 'travel';
      final geminiType = str(extracted['type'])?.toLowerCase() ?? '';
      final lowerName = '${fileName.toLowerCase()} ${name.toLowerCase()} $geminiType';

      const airlines = ['sunexpress', 'sun express', 'thy', 'turkish airlines', 'türk hava',
        'pegasus', 'anadolujet', 'onur air', 'corendon', 'ryanair', 'easyjet',
        'lufthansa', 'emirates', 'qatar', 'wizz', 'flydubai', 'airfrance'];

      if (lowerName.contains('flight') || lowerName.contains('uçuş') || lowerName.contains('boarding') ||
          lowerName.contains('havayol') || lowerName.contains('airline') ||
          airlines.any((a) => lowerName.contains(a))) {
        eventType = 'flight';
      } else if (lowerName.contains('hotel') || lowerName.contains('otel') || lowerName.contains('reservation') ||
          lowerName.contains('booking') || lowerName.contains('airbnb') || lowerName.contains('konaklama')) {
        eventType = 'hotel';
      } else if (lowerName.contains('bus') || lowerName.contains('otobüs') || lowerName.contains('train') || lowerName.contains('tren')) {
        eventType = 'transport';
      } else if (lowerName.contains('ticket') || lowerName.contains('bilet')) {
        eventType = 'ticket';
      }

      if (startDateStr == null) return;
      final startDate = DateTime.tryParse(startDateStr);
      if (startDate == null) return;
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      if (eventType == 'flight' && endDate != null) {
        final depRef = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('calendar_events').add({
          'name': '$name (Departure)',
          'type': eventType,
          'city': city,
          'country': country,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': null,
          'documentId': docId,
          'documentName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final retRef = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('calendar_events').add({
          'name': '$name (Return)',
          'type': eventType,
          'city': city,
          'country': country,
          'startDate': Timestamp.fromDate(endDate),
          'endDate': null,
          'documentId': docId,
          'documentName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _notificationService.scheduleEventReminders(
          eventId: depRef.id, eventName: '$name (Departure)',
          eventType: _eventTypeLabel(eventType), eventDate: startDate, city: city,
        );
        await _notificationService.scheduleEventReminders(
          eventId: retRef.id, eventName: '$name (Return)',
          eventType: _eventTypeLabel(eventType), eventDate: endDate, city: city,
        );

        await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('personal_documents').doc(docId).update({
          'type': eventType,
          'extractedData': extracted,
          'calendarEventId': depRef.id,
          'calendarEventIdReturn': retRef.id,
        });
      } else {
        final eventRef = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('calendar_events').add({
          'name': name,
          'type': eventType,
          'city': city,
          'country': country,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
          'documentId': docId,
          'documentName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _notificationService.scheduleEventReminders(
          eventId: eventRef.id, eventName: name,
          eventType: _eventTypeLabel(eventType), eventDate: startDate, city: city,
        );

        await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('personal_documents').doc(docId).update({
          'type': eventType,
          'extractedData': extracted,
          'calendarEventId': eventRef.id,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Added to calendar: $name', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
            ]),
            backgroundColor: const Color(0xFF4A90D9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Document calendar processing error (planner): $e');
    }
  }

  String _eventTypeLabel(String type) {
    switch (type) {
      case 'flight': return 'flight';
      case 'hotel': return 'hotel reservation';
      case 'transport': return 'transport';
      case 'ticket': return 'ticket';
      default: return 'travel event';
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
        _dirty = true;
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

  Future<bool> _confirmDeleteDoc(String label) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete document?'),
        content: Text('This will permanently remove the $label from your documents and calendar.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _deleteLinkedDocument(String docId, String? url) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('personal_documents').doc(docId).get();
      final data = docSnap.data();
      final calId = data?['calendarEventId'] as String?;
      final calIdReturn = data?['calendarEventIdReturn'] as String?;

      for (final eid in [calId, calIdReturn]) {
        if (eid != null) {
          await FirebaseFirestore.instance
              .collection('users').doc(uid).collection('calendar_events').doc(eid).delete();
          await _notificationService.cancelEventReminders(eid);
        }
      }

      if (url != null) {
        try { await FirebaseStorage.instance.refFromURL(url).delete(); } catch (_) {}
      }

      await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('personal_documents').doc(docId).delete();
    } catch (e) {
      debugPrint('Delete linked document error: $e');
    }
  }

  Future<void> _removeHotelDoc() async {
    if (_pickedHotelFile != null) {
      setState(() { _pickedHotelFile = null; _dirty = true; });
      return;
    }
    if (_existingHotelDocId == null) {
      setState(() { _existingHotelFileName = null; _existingHotelFileUrl = null; _dirty = true; });
      return;
    }
    if (!await _confirmDeleteDoc('hotel document')) return;
    await _deleteLinkedDocument(_existingHotelDocId!, _existingHotelFileUrl);
    if (widget.tripId != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(_authService.currentUser!.uid).collection('trips').doc(widget.tripId)
          .update({'hotelDocumentUrl': null, 'hotelDocumentName': null, 'hotelDocumentId': null});
    }
    if (mounted) {
      setState(() {
        _existingHotelFileName = null;
        _existingHotelFileUrl = null;
        _existingHotelDocId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotel document deleted'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _removeFlightDoc() async {
    if (_pickedFlightFile != null) {
      setState(() { _pickedFlightFile = null; _dirty = true; });
      return;
    }
    if (_existingFlightDocId == null) {
      setState(() { _existingFlightFileName = null; _existingFlightFileUrl = null; _dirty = true; });
      return;
    }
    if (!await _confirmDeleteDoc('flight ticket')) return;
    await _deleteLinkedDocument(_existingFlightDocId!, _existingFlightFileUrl);
    if (widget.tripId != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(_authService.currentUser!.uid).collection('trips').doc(widget.tripId)
          .update({'flightDocumentUrl': null, 'flightDocumentName': null, 'flightDocumentId': null});
    }
    if (mounted) {
      setState(() {
        _existingFlightFileName = null;
        _existingFlightFileUrl = null;
        _existingFlightDocId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flight document deleted'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _savePlan() async {
    if (_formKey.currentState!.validate()) {
      if (_budgetLimitTRY > 0 && _totalBudgetTRY > _budgetLimitTRY) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Over budget by ${(_totalBudgetTRY - _budgetLimitTRY).toStringAsFixed(0)} ₺. Increase your max budget or lower your expenses.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
        return;
      }

      final user = _authService.currentUser;
      if (user == null) return;

      setState(() {
        _isUploading = true;
        _loadingMessage = 'Saving your trip plan...';
      });

      try {
        // Upload Hotel Doc
        String? hotelFileUrl = _existingHotelFileUrl;
        String? hotelDocId = _existingHotelDocId;
        if (_pickedHotelFile != null) {
          hotelFileUrl = await _uploadFile(_pickedHotelFile!, user.uid, 'hotel_documents');
          if (hotelFileUrl != null) {
            hotelDocId = await _syncToPersonalDocuments(user.uid, _pickedHotelFile!.name, hotelFileUrl, _pickedHotelFile!.size);
            if (_pickedHotelFile!.path != null) {
              _processDocumentForCalendar(File(_pickedHotelFile!.path!), _pickedHotelFile!.name, hotelDocId, user.uid);
            }
          }
        }

        // Upload Flight Doc
        String? flightFileUrl = _existingFlightFileUrl;
        String? flightDocId = _existingFlightDocId;
        if (_pickedFlightFile != null) {
          flightFileUrl = await _uploadFile(_pickedFlightFile!, user.uid, 'flight_documents');
          if (flightFileUrl != null) {
            flightDocId = await _syncToPersonalDocuments(user.uid, _pickedFlightFile!.name, flightFileUrl, _pickedFlightFile!.size);
            if (_pickedFlightFile!.path != null) {
              _processDocumentForCalendar(File(_pickedFlightFile!.path!), _pickedFlightFile!.name, flightDocId, user.uid);
            }
          }
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
            if (placeFileUrl != null) {
              final docId = await _syncToPersonalDocuments(user.uid, pf.name, placeFileUrl, pf.size);
              if (pf.path != null) {
                _processDocumentForCalendar(File(pf.path!), pf.name, docId, user.uid);
              }
            }
          }
          
          finalPlaces.add({
            'name': place['name'],
            'price': place['price'],
            'currency': place['currency'] ?? 'TRY',
            'documentUrl': placeFileUrl,
            'documentName': fileName,
          });
        }

        final eventsCol = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('calendar_events');
        if (_hotelCheckIn != null && _hotelCheckOut != null) {
          final eventName = _hotelNameController.text.trim().isNotEmpty
              ? _hotelNameController.text.trim()
              : '${_cityController.text.trim()} Hotel';
          final eventData = {
            'name': eventName,
            'type': 'hotel',
            'city': _cityController.text.trim(),
            'country': _countryController.text.trim(),
            'startDate': Timestamp.fromDate(_hotelCheckIn!),
            'endDate': Timestamp.fromDate(_hotelCheckOut!),
            'source': 'manual',
            'createdAt': FieldValue.serverTimestamp(),
          };
          if (_hotelEventId != null) {
            await eventsCol.doc(_hotelEventId).set(eventData, SetOptions(merge: true));
            await _notificationService.cancelEventReminders(_hotelEventId!);
          } else {
            final ref = await eventsCol.add(eventData);
            _hotelEventId = ref.id;
          }
          await _notificationService.scheduleEventReminders(
            eventId: _hotelEventId!,
            eventName: eventName,
            eventType: 'hotel reservation',
            eventDate: _hotelCheckIn!,
            city: _cityController.text.trim(),
          );
        } else if (_hotelEventId != null) {
          await eventsCol.doc(_hotelEventId).delete();
          await _notificationService.cancelEventReminders(_hotelEventId!);
          _hotelEventId = null;
        }

        final tripData = {
          'city': _cityController.text,
          'country': _countryController.text,
          'hotelName': _hotelNameController.text,
          'hotelPrice': double.tryParse(_hotelPriceController.text) ?? 0,
          'hotelCurrency': _hotelCurrency,
          'hotelCheckIn': _hotelCheckIn != null ? Timestamp.fromDate(_hotelCheckIn!) : null,
          'hotelCheckOut': _hotelCheckOut != null ? Timestamp.fromDate(_hotelCheckOut!) : null,
          'hotelEventId': _hotelEventId,
          'hotelDocumentUrl': hotelFileUrl,
          'hotelDocumentName': _pickedHotelFile?.name ?? _existingHotelFileName,
          'hotelDocumentId': hotelDocId,
          'flightDocumentUrl': flightFileUrl,
          'flightDocumentName': _pickedFlightFile?.name ?? _existingFlightFileName,
          'flightDocumentId': flightDocId,
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
          'checklist': _checklist.map((item) => {'text': item['text'], 'done': item['done']}).toList(),
          'itinerary': _itinerary,
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
          _dirty = false;
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

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (!context.mounted) return;
        if (leave) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Trip'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _coral.withValues(alpha: 0.2),
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
            onChanged: () { if (!_dirty) setState(() => _dirty = true); },
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
                        child: _buildTextField(_cityController, 'City', Icons.location_city,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(_countryController, 'Country', Icons.public,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
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
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
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
                        if (_pickedFlightFile != null || _existingFlightFileName != null)
                          IconButton(
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                            onPressed: _removeFlightDoc,
                          ),
                        TextButton(
                          onPressed: _pickFlightFile,
                          child: Text(_pickedFlightFile != null || _existingFlightFileName != null ? 'Change' : 'Select Ticket', style: const TextStyle(color: Colors.blue)),
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
                    Expanded(child: _buildTextField(_hotelPriceController, 'Hotel Price', Icons.payments, isNumber: true, onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 8),
                    _currencyDropdown(_hotelCurrency, (v) => setState(() => _hotelCurrency = v)),
                  ]),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: _hotelDateChip('Check-in', _hotelCheckIn, true, cardColor, textColor)),
                    const SizedBox(width: 12),
                    Expanded(child: _hotelDateChip('Check-out', _hotelCheckOut, false, cardColor, textColor)),
                  ]),
                  if (_hotelCheckIn != null && _hotelCheckOut != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${_hotelCheckOut!.difference(_hotelCheckIn!).inDays} nights · added to calendar',
                          style: const TextStyle(fontSize: 13, color: _coral, fontWeight: FontWeight.w600)),
                    ),
                  if (_startDate != null && _endDate != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _hotelCheckIn = _startDate;
                          _hotelCheckOut = _endDate;
                          _dirty = true;
                        }),
                        icon: const Icon(Icons.event_repeat_rounded, size: 16, color: _coral),
                        label: Text('Use travel dates', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _coral)),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ),
                  if (_hotelDatesOutOfRange)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Expanded(child: Text('Hotel dates are outside your travel dates', style: GoogleFonts.inter(fontSize: 11, color: Colors.orange))),
                      ]),
                    ),
                  const SizedBox(height: 12),

                  // Hotel Document Upload
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _coral.withValues(alpha: 0.3)),
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
                        if (_pickedHotelFile != null || _existingHotelFileName != null)
                          IconButton(
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                            onPressed: _removeHotelDoc,
                          ),
                        TextButton(
                          onPressed: _pickHotelFile,
                          child: Text(_pickedHotelFile != null || _existingHotelFileName != null ? 'Change' : 'Select File', style: const TextStyle(color: _coral)),
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
                                style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
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

                  // Day-by-day itinerary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Day-by-Day Itinerary', textColor),
                      GestureDetector(
                        onTap: _itineraryLoading ? null : _generateItinerary,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _coral.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _itineraryLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _coral))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 16, color: _coral),
                                    const SizedBox(width: 4),
                                    Text(_itinerary.isEmpty ? 'Generate with AI' : 'Regenerate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _coral)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_itinerary.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Set your travel dates and tap "Generate with AI" for a day-by-day plan.',
                        style: GoogleFonts.inter(fontSize: 13, color: textColor.withValues(alpha: 0.6)),
                      ),
                    )
                  else
                    ...List.generate(_itinerary.length, (i) {
                      final day = _itinerary[i];
                      final activities = (day['activities'] as List).cast<Map<String, dynamic>>();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('Day ${day['day']}: ${day['title']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _dirty = true;
                                    _itinerary.removeAt(i);
                                  }),
                                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...activities.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 52, child: Text(a['time'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _coral))),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a['activity'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                                        if ((a['description'] ?? '').toString().isNotEmpty)
                                          Text(a['description'], style: GoogleFonts.inter(fontSize: 12, color: textColor.withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // Checklist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Checklist', textColor),
                      GestureDetector(
                        onTap: _checklistLoading ? null : () async {
                          final country = _countryController.text.trim();
                          final city = _cityController.text.trim();
                          if (country.isEmpty && city.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Enter a destination first', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            );
                            return;
                          }
                          setState(() => _checklistLoading = true);
                          try {
                            final items = await _geminiService.generateChecklist(country.isNotEmpty ? country : 'World', city.isNotEmpty ? city : 'Trip');
                            if (items != null && mounted) {
                              setState(() {
                                for (final item in items) {
                                  if (!_checklist.any((c) => c['text'] == item)) {
                                    _checklist.add({'text': item, 'done': false});
                                  }
                                }
                              });
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('AI suggestion failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                            );
                          } finally {
                            if (mounted) setState(() => _checklistLoading = false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _coral.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _checklistLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _coral))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 16, color: _coral),
                                    const SizedBox(width: 4),
                                    Text('AI Suggest', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _coral)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
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
                            Expanded(
                              child: TextField(
                                controller: _checklistController,
                                decoration: InputDecoration(
                                  hintText: 'Add item (e.g. Pack passport)',
                                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: isDarkMode ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  prefixIcon: const Icon(Icons.checklist_rounded, color: _coral, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (_checklistController.text.trim().isNotEmpty) {
                                  setState(() {
                                    _dirty = true;
                                    _checklist.add({'text': _checklistController.text.trim(), 'done': false});
                                    _checklistController.clear();
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        if (_checklist.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...List.generate(_checklist.length, (i) {
                            final item = _checklist[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => item['done'] = !item['done']),
                                    child: Icon(
                                      item['done'] ? Icons.check_circle_rounded : Icons.circle_outlined,
                                      color: item['done'] ? const Color(0xFF2ECC71) : Colors.grey,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item['text'],
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: item['done'] ? Colors.grey : textColor,
                                        decoration: item['done'] ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _checklist.removeAt(i)),
                                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Budget Limit
                  _buildSectionTitle('Budget Limit', textColor),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildTextField(_budgetLimitController, 'Max Budget', Icons.account_balance_wallet, isNumber: true, onChanged: (_) => setState(() {}))),
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
                    if (_totalBudgetTRY > _budgetLimitTRY)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('Over budget by ${(_totalBudgetTRY - _budgetLimitTRY).toStringAsFixed(0)} ₺',
                              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ],

                  if (_totalBudgetTRY > 0) ...[
                    const SizedBox(height: 24),
                    _buildBudgetBreakdown(textColor, cardColor),
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
              color: Colors.black.withValues(alpha: 0.3),
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
      ),
    );
  }

  Future<void> _generateItinerary() async {
    final country = _countryController.text.trim();
    final city = _cityController.text.trim();
    if (country.isEmpty && city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a destination first', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set your travel dates first', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      );
      return;
    }

    final days = (_endDate!.difference(_startDate!).inDays + 1).clamp(1, 14);
    setState(() => _itineraryLoading = true);
    String? errorMessage;
    try {
      final plan = await _geminiService.generateItinerary(
        country: country.isNotEmpty ? country : 'World',
        city: city.isNotEmpty ? city : 'Trip',
        days: days,
        places: _places.map((p) => p['name'] as String).toList(),
      );
      if (plan != null) {
        if (mounted) {
          setState(() {
            _dirty = true;
            _itinerary
              ..clear()
              ..addAll(plan.map((day) => {
                'day': day['day'] ?? 1,
                'title': day['title'] ?? '',
                'activities': List<Map<String, dynamic>>.from((day['activities'] ?? []).map((a) => {
                  'time': a['time'] ?? '',
                  'activity': a['activity'] ?? '',
                  'description': a['description'] ?? '',
                })),
              }));
          });
        }
      } else {
        errorMessage = 'Could not generate itinerary, try again';
      }
    } catch (e) {
      errorMessage = 'AI suggestion failed: $e';
    } finally {
      if (mounted) setState(() => _itineraryLoading = false);
    }

    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage, style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Stay', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return res ?? false;
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, ValueChanged<String>? onChanged, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _coral),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildBudgetBreakdown(Color textColor, Color cardColor) {
    if (_rates == null) return const SizedBox.shrink();
    double conv(TextEditingController c, String cur) =>
        _currencyService.convertToTRY(double.tryParse(c.text) ?? 0, cur, _rates!);
    final placesTRY = _places.fold(0.0, (s, p) =>
        s + _currencyService.convertToTRY((p['price'] as num?)?.toDouble() ?? 0, p['currency'] ?? 'TRY', _rates!));

    final items = <Map<String, dynamic>>[
      {'label': 'Hotel', 'icon': Icons.hotel_rounded, 'color': Colors.purple, 'amount': conv(_hotelPriceController, _hotelCurrency)},
      {'label': 'Flight', 'icon': Icons.flight_rounded, 'color': Colors.blue, 'amount': conv(_flightController, _flightCurrency)},
      {'label': 'Food', 'icon': Icons.restaurant_rounded, 'color': Colors.orange, 'amount': conv(_foodController, _foodCurrency)},
      {'label': 'Transport', 'icon': Icons.directions_bus_rounded, 'color': const Color(0xFF2ECC71), 'amount': conv(_transportController, _transportCurrency)},
      {'label': 'Places', 'icon': Icons.place_rounded, 'color': _coral, 'amount': placesTRY},
      {'label': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Colors.grey, 'amount': conv(_otherController, _otherCurrency)},
    ]..removeWhere((e) => (e['amount'] as double) <= 0);

    final total = _totalBudgetTRY;
    if (items.isEmpty || total <= 0) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionTitle('Budget Breakdown', textColor),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(children: items.map((e) {
              final flex = ((e['amount'] as double) / total * 1000).round().clamp(1, 1000);
              return Expanded(flex: flex, child: Container(height: 12, color: e['color'] as Color));
            }).toList()),
          ),
          const SizedBox(height: 16),
          ...items.map((e) {
            final amount = e['amount'] as double;
            final pct = amount / total * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: e['color'] as Color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Icon(e['icon'] as IconData, size: 16, color: e['color'] as Color),
                const SizedBox(width: 6),
                Expanded(child: Text(e['label'] as String, style: GoogleFonts.inter(fontSize: 13, color: textColor))),
                Text('${amount.toStringAsFixed(0)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(width: 8),
                Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              ]),
            );
          }),
        ]),
      ),
    ]);
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

  Widget _hotelDateChip(String label, DateTime? date, bool isCheckIn, Color cardColor, Color textColor) {
    return GestureDetector(
      onTap: () => _pickHotelDate(isCheckIn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _coral.withAlpha(60))),
        child: Row(children: [
          const Icon(Icons.hotel_rounded, size: 16, color: _coral),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: ${_formatDate(date)}', style: TextStyle(fontSize: 13, color: textColor), overflow: TextOverflow.ellipsis)),
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
