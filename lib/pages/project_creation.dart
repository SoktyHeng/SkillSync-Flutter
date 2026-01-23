import 'package:flutter/material.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class ProjectCreation extends StatefulWidget {
  const ProjectCreation({super.key});

  @override
  State<ProjectCreation> createState() => _ProjectCreationState();
}

class _ProjectCreationState extends State<ProjectCreation> {
  final ProjectService _projectService = ProjectService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _techStackController = TextEditingController();
  final _lookingForController = TextEditingController();
  final _durationController = TextEditingController();

  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _techStackController.addListener(_onFormChanged);
    _lookingForController.addListener(_onFormChanged);
    _durationController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    final hasContent =
        _titleController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _techStackController.text.isNotEmpty ||
        _lookingForController.text.isNotEmpty ||
        _durationController.text.isNotEmpty;

    if (hasContent != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasContent;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    _lookingForController.dispose();
    _durationController.dispose();
    super.dispose();
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

      final duration = _durationController.text.trim().isNotEmpty
          ? _durationController.text.trim()
          : null;

      await _projectService.createProject(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        techStack: techStack,
        lookingFor: lookingFor,
        duration: duration,
      );

      if (mounted) {
        _showSnackBar('Project posted successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error posting project: ${e.toString()}');
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
          title: const Text('Create New Project'),
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
                  TextField(
                    controller: _durationController,
                    decoration: _buildInputDecoration(
                      hint: 'e.g., 2 weeks, 3 months, Ongoing',
                    ),
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
                              'Save',
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
