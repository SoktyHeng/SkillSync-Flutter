import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class ProjectEdit extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> project;

  const ProjectEdit({
    super.key,
    required this.projectId,
    required this.project,
  });

  @override
  State<ProjectEdit> createState() => _ProjectEditState();
}

class _ProjectEditState extends State<ProjectEdit> {
  final ProjectService _projectService = ProjectService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _techStackController;
  late TextEditingController _lookingForController;

  DateTimeRange? _selectedDateRange;
  bool _isOngoing = false;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(
      text: widget.project['title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.project['description'] ?? '',
    );

    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    _techStackController = TextEditingController(
      text: techStack.join(', '),
    );

    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);
    _lookingForController = TextEditingController(
      text: lookingFor.join(', '),
    );

    // Parse duration
    final duration = widget.project['duration'] as String?;
    if (duration == 'Ongoing') {
      _isOngoing = true;
    } else if (duration != null && duration.isNotEmpty) {
      _parseDateRange(duration);
    }

    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _techStackController.addListener(_onFormChanged);
    _lookingForController.addListener(_onFormChanged);
  }

  void _parseDateRange(String duration) {
    try {
      final parts = duration.split(' - ');
      if (parts.length == 2) {
        final dateFormat = DateFormat('d MMM yyyy');
        final start = dateFormat.parse(parts[0]);
        final end = dateFormat.parse(parts[1]);
        _selectedDateRange = DateTimeRange(start: start, end: end);
      }
    } catch (e) {
      debugPrint('Error parsing date range: $e');
    }
  }

  void _onFormChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    _lookingForController.dispose();
    super.dispose();
  }

  String _formatDateRange(DateTimeRange range) {
    final dateFormat = DateFormat('d MMM yyyy');
    return '${dateFormat.format(range.start)} - ${dateFormat.format(range.end)}';
  }

  String? _getDurationString() {
    if (_isOngoing) {
      return 'Ongoing';
    } else if (_selectedDateRange != null) {
      return _formatDateRange(_selectedDateRange!);
    }
    return null;
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1, 1);
    final lastDate = DateTime(now.year + 5, 12, 31);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple[500]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _isOngoing = false;
        _onFormChanged();
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, false);
              await _saveProject();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple[500],
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveProject() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a project title');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Please enter a description');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final techStack = _techStackController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final lookingFor = _lookingForController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final duration = _getDurationString();

      await _projectService.updateProject(
        projectId: widget.projectId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        techStack: techStack,
        lookingFor: lookingFor,
        duration: duration,
      );

      if (mounted) {
        _showSnackBar('Project updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error updating project: ${e.toString()}');
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

  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.deepPurple[500]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Edit Project'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Project Title',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: _buildInputDecoration(
                      hint: 'Enter your project title',
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: _buildInputDecoration(
                      hint:
                          'Describe your project and what you\'re looking to build...',
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Tech Stack (comma separated)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _techStackController,
                    decoration: _buildInputDecoration(
                      hint: 'e.g., React, Node.js, MongoDB',
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Looking For (roles needed)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lookingForController,
                    decoration: _buildInputDecoration(
                      hint: 'e.g., Frontend Developer, UI Designer',
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Duration',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isOngoing ? null : _selectDateRange,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _isOngoing ? Colors.grey[100] : Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: _isOngoing
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDateRange != null
                                  ? _formatDateRange(_selectedDateRange!)
                                  : 'Select date range',
                              style: TextStyle(
                                color: _selectedDateRange != null
                                    ? Colors.black
                                    : Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_selectedDateRange != null && !_isOngoing)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDateRange = null;
                                  _onFormChanged();
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _isOngoing,
                          onChanged: (value) {
                            setState(() {
                              _isOngoing = value ?? false;
                              if (_isOngoing) {
                                _selectedDateRange = null;
                              }
                              _onFormChanged();
                            });
                          },
                          activeColor: Colors.deepPurple[500],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isOngoing = !_isOngoing;
                            if (_isOngoing) {
                              _selectedDateRange = null;
                            }
                            _onFormChanged();
                          });
                        },
                        child: const Text(
                          'Ongoing project (no end date)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple[500],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
