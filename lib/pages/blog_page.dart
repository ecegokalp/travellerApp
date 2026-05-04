import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';

class BlogPage extends StatefulWidget {
  final String? initialCountry;
  final String? initialCity;
  
  const BlogPage({
    super.key,
    this.initialCountry,
    this.initialCity,
  });

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final AuthService _authService = AuthService();
  final GeminiService _geminiService = GeminiService();
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  
  String? _selectedCountry;
  String? _selectedCity;
  List<String> _cities = [];
  bool _isGeneratingAI = false;
  File? _selectedImage;
  bool _isUploading = false;

  final Map<String, List<String>> _countryCities = {
    'Turkey': ['Istanbul', 'Ankara', 'Izmir', 'Antalya', 'Bursa', 'Cappadocia', 'Mardin', 'Fethiye'],
    'France': ['Paris', 'Lyon', 'Marseille', 'Nice', 'Bordeaux', 'Strasbourg'],
    'Italy': ['Rome', 'Milan', 'Venice', 'Florence', 'Naples', 'Pisa', 'Amalfi'],
    'USA': ['New York', 'Los Angeles', 'Chicago', 'Miami', 'San Francisco', 'Washington D.C.'],
    'Japan': ['Tokyo', 'Osaka', 'Kyoto', 'Yokohama', 'Sapporo', 'Nara'],
    'Germany': ['Berlin', 'Munich', 'Hamburg', 'Frankfurt', 'Cologne', 'Stuttgart'],
    'UK': ['London', 'Edinburgh', 'Manchester', 'Birmingham', 'Liverpool', 'Oxford'],
    'Spain': ['Madrid', 'Barcelona', 'Seville', 'Valencia', 'Malaga', 'Ibiza'],
    'Greece': ['Athens', 'Thessaloniki', 'Santorini', 'Mykonos', 'Crete', 'Rhodes'],
    'Egypt': ['Cairo', 'Alexandria', 'Luxor', 'Giza', 'Sharm El Sheikh'],
    'Netherlands': ['Amsterdam', 'Rotterdam', 'The Hague', 'Utrecht'],
    'Switzerland': ['Zurich', 'Geneva', 'Basel', 'Bern', 'Zermatt'],
    'UAE': ['Dubai', 'Abu Dhabi', 'Sharjah'],
    'Jordan': ['Amman', 'Petra', 'Aqaba', 'Wadi Rum'],
    'India': ['Mumbai', 'Delhi', 'Bangalore', 'Agra', 'Jaipur'],
    'Brazil': ['Rio de Janeiro', 'Sao Paulo', 'Brasilia', 'Salvador'],
    'Canada': ['Toronto', 'Vancouver', 'Montreal', 'Ottawa', 'Quebec City'],
    'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Gold Coast'],
    'China': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen', 'Xi\'an'],
    'Portugal': ['Lisbon', 'Porto', 'Algarve', 'Sintra'],
    'Mexico': ['Mexico City', 'Cancun', 'Tulum', 'Playa del Carmen'],
    'Thailand': ['Bangkok', 'Phuket', 'Chiang Mai', 'Pattaya'],
    'South Korea': ['Seoul', 'Busan', 'Incheon', 'Jeju'],
    'Russia': ['Moscow', 'Saint Petersburg', 'Kazan', 'Sochi'],
    'Argentina': ['Buenos Aires', 'Mendoza', 'Bariloche', 'Iguazu'],
    'Norway': ['Oslo', 'Bergen', 'Tromso', 'Stavanger'],
    'Sweden': ['Stockholm', 'Gothenburg', 'Malmo'],
  };

  List<String> get _countries => _countryCities.keys.toList();

  static const _accent = Color(0xFFFF6B6B);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    if (widget.initialCountry != null) {
      _selectedCountry = widget.initialCountry;
      _loadCities(_selectedCountry!);
    }
  }

  void _loadCities(String country) {
    setState(() {
      _cities = _countryCities[country] ?? [];
      _selectedCity = null;
      
      // Eğer dışarıdan (Discover'dan) bir şehir geldiyse ve listede yoksa ekle
      if (widget.initialCity != null && !_cities.contains(widget.initialCity)) {
        _cities = [widget.initialCity!, ..._cities];
        _selectedCity = widget.initialCity;
      } else if (widget.initialCity != null) {
        _selectedCity = widget.initialCity;
      }
    });
  }

  Future<void> _generateAIContent() async {
    if (_selectedCountry == null || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select country and city first!')),
      );
      return;
    }

    setState(() => _isGeneratingAI = true);

    try {
      final content = await _geminiService.generateBlogContent(_selectedCountry!, _selectedCity!);
      if (content != null) {
        setState(() => _contentController.text = content);
      } else {
        throw Exception("AI returned no content");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _saveBlog() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_blogs')
            .child(user.uid)
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('blogs')
          .add({
        'country': _selectedCountry,
        'city': _selectedCity,
        'content': _contentController.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _contentController.clear();
        setState(() {
          _selectedImage = null;
          _selectedCountry = null;
          _selectedCity = null;
          _cities = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story posted!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _darkText;

    return Scaffold(
      appBar: AppBar(
        title: Text('Travel Blog', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown('Country', _selectedCountry, _countries, (val) {
                      if (val != null) {
                        setState(() => _selectedCountry = val);
                        _loadCities(val);
                      }
                    }, Icons.public),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown('City', _selectedCity, _cities, (val) => setState(() => _selectedCity = val), Icons.location_city, 
                      enabled: _selectedCountry != null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Story', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                  TextButton.icon(
                    onPressed: _isGeneratingAI ? null : _generateAIContent,
                    icon: _isGeneratingAI 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                      : const Icon(Icons.auto_awesome, size: 16, color: _accent),
                    label: Text(_isGeneratingAI ? 'Writing...' : 'AI Write', style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              
              _buildTextField(_contentController, 'Tell your adventure...', Icons.edit_note, textColor, maxLines: 6),
              const SizedBox(height: 20),
              
              _buildImagePicker(isDark),
              const SizedBox(height: 32),
              
              _buildPostButton(),
              const SizedBox(height: 40),
              
              Text('Recent Stories', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              _buildRecentBlogs(user: _authService.currentUser),
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı UI Widget'ları (Kısa tutuldu)
  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged, IconData icon, {bool enabled = true}) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.toSet().map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _accent, size: 18),
        filled: true,
        fillColor: Theme.of(context).cardColor.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: (val) => val == null ? 'Required' : null,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color textColor, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: textColor),
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: _accent),
        filled: true,
        fillColor: Theme.of(context).cardColor.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Please write something' : null,
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: _selectedImage != null
            ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_selectedImage!, fit: BoxFit.cover))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_a_photo_outlined, size: 30, color: _accent),
                Text('Add Photo', style: GoogleFonts.inter(color: _warmGray)),
              ]),
      ),
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _saveBlog,
        style: ElevatedButton.styleFrom(backgroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : Text('Post Blog', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildRecentBlogs({User? user}) {
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('blogs').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final blog = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text('${blog['city']}, ${blog['country']}', style: const TextStyle(fontWeight: FontWeight.bold, color: _accent)),
                subtitle: Text(blog['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => docs[index].reference.delete()),
              ),
            );
          },
        );
      },
    );
  }
}
