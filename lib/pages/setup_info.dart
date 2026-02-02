import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skillsync_sp2/constants/app_data.dart';
import 'package:skillsync_sp2/pages/navigation_bar.dart';
import 'package:skillsync_sp2/services/user_service.dart';

class SetupInfoPage extends StatefulWidget {
  const SetupInfoPage({super.key});

  @override
  State<SetupInfoPage> createState() => _SetupInfoPageState();
}

class _SetupInfoPageState extends State<SetupInfoPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();

  final UserService _userService = UserService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  String? _selectedMajor;
  String? _selectedYear;
  final List<String> _selectedSkills = [];

  List<String> get _majors => AppData.majors;
  List<String> get _years => AppData.years;
  List<String> get _availableSkills => AppData.skills;

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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.deepPurple[500]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  void _showSkillsBottomSheet() {
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredSkills = _availableSkills
                .where(
                  (skill) =>
                      skill.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();

            final bool canAddCustomSkill =
                searchQuery.trim().isNotEmpty &&
                !_availableSkills
                    .map((s) => s.toLowerCase())
                    .contains(searchQuery.trim().toLowerCase()) &&
                !_selectedSkills
                    .map((s) => s.toLowerCase())
                    .contains(searchQuery.trim().toLowerCase());

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
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
                        'Choose skills or add your own',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      // Search field
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search or add a skill...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.deepPurple[500]!,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Add custom skill button
                      if (canAddCustomSkill)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              final customSkill = searchQuery.trim();
                              setModalState(() {
                                _selectedSkills.add(customSkill);
                                searchController.clear();
                                searchQuery = '';
                              });
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.deepPurple[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle,
                                    color: Colors.deepPurple[500],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Add "${searchQuery.trim()}" as a skill',
                                      style: TextStyle(
                                        color: Colors.deepPurple[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Skills list
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Show selected custom skills (not in predefined list)
                              ..._selectedSkills
                                  .where(
                                    (skill) => !_availableSkills
                                        .map((s) => s.toLowerCase())
                                        .contains(skill.toLowerCase()),
                                  )
                                  .where(
                                    (skill) =>
                                        searchQuery.isEmpty ||
                                        skill.toLowerCase().contains(
                                          searchQuery.toLowerCase(),
                                        ),
                                  )
                                  .map((skill) {
                                    return FilterChip(
                                      label: Text(skill),
                                      selected: true,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          _selectedSkills.remove(skill);
                                        });
                                        setState(() {});
                                      },
                                      selectedColor: Colors.deepPurple[500]
                                          ?.withValues(alpha: 0.2),
                                      checkmarkColor: Colors.deepPurple[700],
                                      labelStyle: TextStyle(
                                        color: Colors.deepPurple[500],
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: Colors.deepPurple[500]!,
                                        ),
                                      ),
                                    );
                                  }),
                              // Show filtered predefined skills
                              ...filteredSkills.map((skill) {
                                final isSelected = _selectedSkills.contains(
                                  skill,
                                );
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
                                  selectedColor: Colors.deepPurple[500]
                                      ?.withValues(alpha: 0.2),
                                  checkmarkColor: Colors.deepPurple[700],
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.deepPurple[500]
                                        : Colors.black,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.deepPurple[500]!
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                );
                              }),
                            ],
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
                            backgroundColor: Colors.deepPurple[500],
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

  Future<void> _saveProfile() async {
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

    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.saveUserProfile(
        name: _nameController.text.trim(),
        major: _selectedMajor!,
        yearOfStudy: _selectedYear!,
        phoneNumber: _phoneController.text.trim(),
        skills: _selectedSkills,
        githubUrl: _githubController.text.trim().isNotEmpty
            ? _githubController.text.trim()
            : null,
      );

      if (mounted) {
        _showSnackBar('Profile saved successfully!');
        // Navigate to home page after successful save
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const NavigationPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 80,
                        color: Colors.deepPurple[500],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Complete Your Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    'Tell us more about yourself to get started',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),

                // Email display (from Firebase Auth)
                if (_currentUser?.email != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[500]?.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.deepPurple[500]!.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: Colors.deepPurple[500],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentUser!.email!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified,
                          color: Colors.green[600],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

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
                  isExpanded: true,
                  items: _majors.map((major) {
                    return DropdownMenuItem(
                      value: major,
                      child: Text(
                        major,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    return DropdownMenuItem(value: year, child: Text(year));
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                              Icon(
                                Icons.add_circle_outline,
                                color: Colors.grey[600],
                              ),
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
                                  style: TextStyle(
                                    color: Colors.deepPurple[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: Colors.deepPurple[500]
                                    ?.withValues(alpha: 0.1),
                                deleteIcon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.deepPurple[500],
                                ),
                                onDeleted: () {
                                  setState(() {
                                    _selectedSkills.remove(skill);
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: Colors.deepPurple[500]!,
                                  ),
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
                    suffixIcon: Icon(Icons.link, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(
                        color: Colors.deepPurple[500]!,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[500],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.deepPurple[500]
                          ?.withValues(alpha: 0.6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
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
