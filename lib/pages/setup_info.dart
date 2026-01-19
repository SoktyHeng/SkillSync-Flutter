import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetupInfoPage extends StatefulWidget {
  const SetupInfoPage({super.key});

  @override
  State<SetupInfoPage> createState() => _SetupInfoPageState();
}

class _SetupInfoPageState extends State<SetupInfoPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();

  String? _selectedMajor;
  String? _selectedYear;
  final List<String> _selectedSkills = [];

  final List<String> _majors = [
    'Computer Science',
    'Information Technology',
    'Software Engineering',
    'Data Science',
    'Cybersecurity',
    'Artificial Intelligence',
    'Business Administration',
    'Marketing',
    'Finance',
    'Graphic Design',
    'Other',
  ];

  final List<String> _years = [
    'Year 1',
    'Year 2',
    'Year 3',
    'Year 4',
    'Year 5+',
    'Graduate',
  ];

  final List<String> _availableSkills = [
    'Flutter',
    'React',
    'Python',
    'Java',
    'JavaScript',
    'TypeScript',
    'Node.js',
    'Swift',
    'Kotlin',
    'C++',
    'Go',
    'Rust',
    'SQL',
    'MongoDB',
    'Firebase',
    'AWS',
    'Docker',
    'Git',
    'UI/UX Design',
    'Machine Learning',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Colors.purple,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  void _showSkillsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Your Skills',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose skills that best describe your expertise',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSkills.map((skill) {
                              final isSelected =
                                  _selectedSkills.contains(skill);
                              return FilterChip(
                                label: Text(skill),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      _selectedSkills.add(skill);
                                    } else {
                                      _selectedSkills.remove(skill);
                                    }
                                  });
                                  setState(() {});
                                },
                                selectedColor: Colors.purple.withValues(alpha: 0.2),
                                checkmarkColor: Colors.purple,
                                labelStyle: TextStyle(
                                  color:
                                      isSelected ? Colors.purple : Colors.black,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.purple
                                        : Colors.grey[300]!,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _saveProfile() {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name');
      return;
    }
    if (_selectedMajor == null) {
      _showSnackBar('Please select your major');
      return;
    }
    if (_selectedYear == null) {
      _showSnackBar('Please select your year of study');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Please enter your phone number');
      return;
    }
    if (_selectedSkills.isEmpty) {
      _showSnackBar('Please select at least one skill');
      return;
    }

    // TODO: Save profile to Firebase
    _showSnackBar('Profile saved successfully!');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Header
                const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 80,
                        color: Colors.purple,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Complete Your Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    'Tell us more about yourself to get started',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 40),

                // Name field
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _buildInputDecoration(
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    hint: 'Enter your full name',
                  ),
                ),
                const SizedBox(height: 20),

                // Major dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedMajor,
                  decoration: _buildInputDecoration(
                    label: 'Major',
                    icon: Icons.school_outlined,
                  ),
                  items: _majors.map((major) {
                    return DropdownMenuItem(
                      value: major,
                      child: Text(major),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMajor = value;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 20),

                // Year of study dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedYear,
                  decoration: _buildInputDecoration(
                    label: 'Year of Study',
                    icon: Icons.calendar_today_outlined,
                  ),
                  items: _years.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 20),

                // Phone number field
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: _buildInputDecoration(
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    hint: 'Enter your phone number',
                  ),
                ),
                const SizedBox(height: 20),

                // Skills section
                const Text(
                  'Skills',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showSkillsBottomSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: _selectedSkills.isEmpty
                        ? Row(
                            children: [
                              Icon(Icons.add_circle_outline,
                                  color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Text(
                                'Tap to select your skills',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedSkills.map((skill) {
                              return Chip(
                                label: Text(
                                  skill,
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: Colors.purple.withValues(alpha: 0.1),
                                deleteIcon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.purple,
                                ),
                                onDeleted: () {
                                  setState(() {
                                    _selectedSkills.remove(skill);
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(color: Colors.purple),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // GitHub link field (optional)
                TextField(
                  controller: _githubController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'GitHub Profile (Optional)',
                    hintText: 'https://github.com/username',
                    prefixIcon: const Icon(Icons.code),
                    suffixIcon: Icon(
                      Icons.link,
                      color: Colors.grey[400],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(
                        color: Colors.purple,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Link your GitHub to showcase your projects',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      'Save Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
