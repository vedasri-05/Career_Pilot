import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../resume/upload_resume_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();

  User? get currentUser => _auth.currentUser;

  Map<String, dynamic>? userProfile;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> resumes = [];
  String? activeResumeId;

  bool isLoading = true;
  bool isSavingName = false;
  bool isSavingCareerGoal = false;
  bool isSelectingResume = false;
  bool isUploadingPhoto = false;
  String? deletingResumeId;

  // In-memory preview of the selected image before/during upload
  Uint8List? _tempSelectedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ------------------------------------------------------------
  // LOAD PROFILE
  // ------------------------------------------------------------

  Future<void> _loadProfile() async {
    final User? user = currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> profileDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final QuerySnapshot<Map<String, dynamic>> resumeSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('resumes')
              .orderBy('uploadedAt', descending: true)
              .get();

      if (!mounted) return;

      setState(() {
        userProfile = profileDocument.data();
        resumes = resumeSnapshot.docs;
        activeResumeId = userProfile?['activeResumeId'] as String?;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: $e'),
          backgroundColor: AppTheme.rose,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // PROFILE IMAGE SELECTION & UPLOAD
  // ------------------------------------------------------------

  Future<void> _pickAndUploadProfileImage() async {
    final User? user = currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to update your profile photo.'),
        ),
      );
      return;
    }

    if (isUploadingPhoto) return; // Prevent duplicate uploads

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file == null) {
        // User cancelled selection
        return;
      }
      final extension = (file.extension ?? '').toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unsupported format. Please choose a JPG, PNG, or WEBP image.',
            ),
            backgroundColor: AppTheme.rose,
          ),
        );
        return;
      }

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The selected image is empty. Please choose another.',
            ),
            backgroundColor: AppTheme.rose,
          ),
        );
        return;
      }

      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image size must be less than 5 MB.'),
            backgroundColor: AppTheme.rose,
          ),
        );
        return;
      }

      // Show immediate local preview and enter uploading state
      setState(() {
        _tempSelectedImageBytes = bytes;
        isUploadingPhoto = true;
      });

      String? downloadUrl;
      bool storageWorked = false;

      // 1. Attempt upload to Firebase Storage
      try {
        downloadUrl = await _storageService.uploadProfileImage(
          file: file,
          userId: user.uid,
        );
        storageWorked = true;
      } catch (storageError) {
        // Firebase Storage might not be enabled or rule may need deployment
        downloadUrl = null;
        storageWorked = false;
      }

      if (!mounted) return;

      if (storageWorked && downloadUrl != null) {
        // Persist download URL in Firestore
        await _firestoreService.updateUserProfile(user.uid, {
          'profileImageUrl': downloadUrl,
          'photoUrl': downloadUrl,
        });

        try {
          await user.updatePhotoURL(downloadUrl);
        } catch (_) {}

        if (!mounted) return;

        setState(() {
          userProfile = {
            ...?userProfile,
            'profileImageUrl': downloadUrl,
            'photoUrl': downloadUrl,
          };
          isUploadingPhoto = false;
          _tempSelectedImageBytes = null; // Revert to network source
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully! 🎉'),
            backgroundColor: AppTheme.teal,
          ),
        );
      } else {
        // Fallback: persistent Base64 storage in Firestore document
        final String base64String = base64Encode(bytes);

        await _firestoreService.updateUserProfile(user.uid, {
          'photoBase64': base64String,
          'profileImageUrl': '',
        });

        if (!mounted) return;

        setState(() {
          userProfile = {
            ...?userProfile,
            'photoBase64': base64String,
            'profileImageUrl': '',
          };
          isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo saved successfully! 🎉'),
            backgroundColor: AppTheme.teal,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isUploadingPhoto = false;
        _tempSelectedImageBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update profile photo: $e'),
          backgroundColor: AppTheme.rose,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // AVATAR WIDGET BUILDER
  // ------------------------------------------------------------

  Widget _buildAvatarWidget() {
    final String photoUrl =
        userProfile?['profileImageUrl'] as String? ??
        userProfile?['photoUrl'] as String? ??
        currentUser?.photoURL ??
        '';

    final String photoBase64 = userProfile?['photoBase64'] as String? ?? '';
    final String name = userProfile?['name'] as String? ?? 'User';

    ImageProvider? imageProvider;
    if (_tempSelectedImageBytes != null) {
      imageProvider = MemoryImage(_tempSelectedImageBytes!);
    } else if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      imageProvider = NetworkImage(photoUrl);
    } else if (photoBase64.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(photoBase64));
      } catch (_) {
        imageProvider = null;
      }
    }

    String initials = '';
    final parts = name.trim().split(' ');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      initials += parts.first[0].toUpperCase();
    }
    if (parts.length > 1 && parts.last.isNotEmpty) {
      initials += parts.last[0].toUpperCase();
    }
    if (initials.isEmpty) initials = 'U';

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer gradient ring
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: imageProvider != null
                        ? Image(
                            image: imageProvider,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackInitials(initials);
                            },
                          )
                        : _buildFallbackInitials(initials),
                  ),
                ),
              ),
            ),
          ),

          // Uploading overlay indicator
          if (isUploadingPhoto)
            Container(
              width: 106,
              height: 106,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Edit camera badge button
          Positioned(
            bottom: 2,
            right: 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isUploadingPhoto ? null : _pickAndUploadProfileImage,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackInitials(String initials) {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EDIT NAME DIALOG
  // ------------------------------------------------------------

  Future<void> _showEditNameDialog() async {
    final User? user = currentUser;
    if (user == null) return;

    final TextEditingController nameController = TextEditingController(
      text: userProfile?['name'] ?? '',
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
                  SizedBox(width: 10),
                  Text('Edit Full Name'),
                ],
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingName
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSavingName
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final String newName = nameController.text.trim();

                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          setDialogState(() => isSavingName = true);
                          setState(() => isSavingName = true);

                          try {
                            await _firestoreService.updateUserProfile(
                              user.uid,
                              {'name': newName},
                            );

                            try {
                              await user.updateDisplayName(newName);
                            } catch (_) {}

                            if (!mounted) return;

                            setState(() {
                              userProfile = {...?userProfile, 'name': newName};
                              isSavingName = false;
                            });

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Name updated successfully'),
                                backgroundColor: AppTheme.teal,
                              ),
                            );
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSavingName = false);
                            }
                            if (!mounted) return;
                            setState(() => isSavingName = false);

                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to update name: $e'),
                                backgroundColor: AppTheme.rose,
                              ),
                            );
                          }
                        },
                  child: isSavingName
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  // ------------------------------------------------------------
  // EDIT CAREER GOAL DIALOG
  // ------------------------------------------------------------

  Future<void> _showEditCareerGoalDialog() async {
    final User? user = currentUser;
    if (user == null) return;

    final String initialGoal = (userProfile?['careerGoal'] ?? '')
        .toString()
        .trim();
    final bool isStandardGoal =
        UserModel.careerGoals.contains(initialGoal) && initialGoal != 'Other';

    String? dialogSelectedGoal = isStandardGoal
        ? initialGoal
        : (initialGoal.isNotEmpty ? 'Other' : null);

    final TextEditingController otherGoalController = TextEditingController(
      text: (!isStandardGoal && initialGoal.isNotEmpty) ? initialGoal : '',
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.flag_outlined, color: AppTheme.primaryBlue),
                  SizedBox(width: 10),
                  Text('Edit Career Goal'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: dialogSelectedGoal,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textMuted,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Career Goal',
                          hintText: 'Select your career goal',
                          prefixIcon: Icon(Icons.rocket_launch_outlined),
                        ),
                        hint: const Text(
                          'Select your career goal',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        items: UserModel.careerGoals.map((goal) {
                          return DropdownMenuItem<String>(
                            value: goal,
                            child: Text(
                              goal,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            dialogSelectedGoal = value;
                            if (value != 'Other') {
                              otherGoalController.clear();
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select your career goal';
                          }
                          return null;
                        },
                      ),
                      if (dialogSelectedGoal == 'Other') ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: otherGoalController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Specify Career Goal',
                            hintText: 'e.g. Blockchain Developer',
                            prefixIcon: Icon(Icons.edit_note_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please specify your career goal';
                            }
                            if (value.trim().length < 2) {
                              return 'Please enter a valid career goal';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingCareerGoal
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSavingCareerGoal
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final String newGoal = dialogSelectedGoal == 'Other'
                              ? otherGoalController.text.trim()
                              : (dialogSelectedGoal ?? '').trim();

                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          setDialogState(() => isSavingCareerGoal = true);
                          setState(() => isSavingCareerGoal = true);

                          try {
                            await _firestoreService.updateUserProfile(
                              user.uid,
                              {'careerGoal': newGoal},
                            );

                            if (!mounted) return;

                            setState(() {
                              userProfile = {
                                ...?userProfile,
                                'careerGoal': newGoal,
                              };
                              isSavingCareerGoal = false;
                            });

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Career goal updated successfully',
                                ),
                                backgroundColor: AppTheme.teal,
                              ),
                            );
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSavingCareerGoal = false);
                            }
                            if (!mounted) return;
                            setState(() => isSavingCareerGoal = false);

                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to update goal: $e'),
                                backgroundColor: AppTheme.rose,
                              ),
                            );
                          }
                        },
                  child: isSavingCareerGoal
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    otherGoalController.dispose();
  }

  // ------------------------------------------------------------
  // SELECT ACTIVE RESUME
  // ------------------------------------------------------------

  Future<void> _selectActiveResume(String resumeId) async {
    final User? user = currentUser;
    if (user == null || resumeId == activeResumeId) return;

    setState(() {
      isSelectingResume = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'activeResumeId': resumeId},
      );

      if (!mounted) return;

      setState(() {
        activeResumeId = resumeId;
        isSelectingResume = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Active resume updated'),
          backgroundColor: AppTheme.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSelectingResume = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select resume: $e'),
          backgroundColor: AppTheme.rose,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // DELETE RESUME
  // ------------------------------------------------------------

  Future<void> _deleteResume(String resumeId, String fileName) async {
    final User? user = currentUser;
    if (user == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Delete Resume?'),
          content: Text('Are you sure you want to delete "$fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      deletingResumeId = resumeId;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('resumes')
          .doc(resumeId)
          .delete();

      String? newActiveResumeId = activeResumeId;
      if (activeResumeId == resumeId) {
        newActiveResumeId = null;
        final remainingResumes = resumes
            .where((resume) => resume.id != resumeId)
            .toList();
        if (remainingResumes.isNotEmpty) {
          newActiveResumeId = remainingResumes.first.id;
        }

        if (newActiveResumeId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'activeResumeId': newActiveResumeId});
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'activeResumeId': FieldValue.delete()});
        }
      }

      if (!mounted) return;

      setState(() {
        resumes = resumes.where((resume) => resume.id != resumeId).toList();
        activeResumeId = newActiveResumeId;
        deletingResumeId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resume deleted successfully'),
          backgroundColor: AppTheme.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        deletingResumeId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete resume: $e'),
          backgroundColor: AppTheme.rose,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // ADD RESUME
  // ------------------------------------------------------------

  Future<void> _addResume() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadResumeScreen()),
    );
    await _loadProfile();
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to log out of CareerPilot?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ------------------------------------------------------------
  // INFO CARD COMPONENT
  // ------------------------------------------------------------

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty
                        ? AppTheme.textMuted
                        : AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            Material(
              color: Colors.transparent,
              child: IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.primaryBlue,
                tooltip: 'Edit $title',
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // RESUME CARD COMPONENT
  // ------------------------------------------------------------

  Widget _buildResumeCard(QueryDocumentSnapshot<Map<String, dynamic>> resume) {
    final Map<String, dynamic> data = resume.data();
    final String fileName = data['fileName'] ?? 'Resume';
    final String fileType = (data['fileType'] ?? 'FILE')
        .toString()
        .toUpperCase();
    final bool isActive = resume.id == activeResumeId;
    final bool isDeleting = deletingResumeId == resume.id;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryBlue.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
          width: isActive ? 1.8 : 1,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.rose,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fileType,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSelectingResume || isActive
                      ? null
                      : () => _selectActiveResume(resume.id),
                  icon: isSelectingResume && !isActive
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.star_outline, size: 18),
                  label: Text(
                    isActive ? 'Currently Active' : 'Set as Active',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isDeleting
                    ? null
                    : () => _deleteResume(resume.id, fileName),
                icon: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, color: AppTheme.rose),
                tooltip: 'Delete Resume',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE COMPONENT
  // ------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textDark,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildEmptyResumeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 30,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No resumes uploaded yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload your resume to get instant AI analysis and personalized career insights.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMedium),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addResume,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Upload Resume'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(180, 44)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveResumeNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your selected resume is active and ready for AI analysis and career recommendations.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // MAIN BUILD METHOD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.colorfulBackgroundGradient,
              ),
              child: RefreshIndicator(
                onRefresh: _loadProfile,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    final horizontalPadding = isWide ? 40.0 : 20.0;

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PROFILE HEADER & AVATAR (FULL-WIDTH CARD)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(26),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.22,
                                    ),
                                    width: 1.5,
                                  ),
                                  boxShadow: AppTheme.softShadow,
                                ),
                                child: Column(
                                  children: [
                                    _buildAvatarWidget(),
                                    const SizedBox(height: 14),
                                    Text(
                                      userProfile?['name'] ?? 'User',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userProfile?['email'] ??
                                          currentUser?.email ??
                                          '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    InkWell(
                                      onTap: isUploadingPhoto
                                          ? null
                                          : _pickAndUploadProfileImage,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primaryBlue
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.photo_camera_rounded,
                                              size: 16,
                                              color: isUploadingPhoto
                                                  ? Colors.grey
                                                  : AppTheme.primaryBlue,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isUploadingPhoto
                                                  ? 'Uploading...'
                                                  : 'Change Profile Photo',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isUploadingPhoto
                                                    ? Colors.grey
                                                    : AppTheme.primaryBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),

                              // RESPONSIVE LAYOUT FOR PERSONAL INFO AND RESUMES
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // COLUMN 1: PERSONAL INFORMATION
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionTitle(
                                            'Personal Information',
                                          ),
                                          const SizedBox(height: 12),
                                          _buildInfoCard(
                                            icon: Icons.person_outline,
                                            title: 'Full Name',
                                            value: userProfile?['name'] ?? '',
                                            onEdit: _showEditNameDialog,
                                          ),
                                          _buildInfoCard(
                                            icon: Icons.email_outlined,
                                            title: 'Email Address',
                                            value:
                                                userProfile?['email'] ??
                                                currentUser?.email ??
                                                '',
                                          ),
                                          _buildInfoCard(
                                            icon: Icons.flag_outlined,
                                            title: 'Career Goal',
                                            value:
                                                userProfile?['careerGoal'] ??
                                                '',
                                            onEdit: _showEditCareerGoalDialog,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // COLUMN 2: RESUMES & ACTIONS
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildSectionTitle('My Resumes'),
                                              TextButton.icon(
                                                onPressed: _addResume,
                                                icon: const Icon(
                                                  Icons.add_rounded,
                                                  size: 18,
                                                ),
                                                label: const Text('Add Resume'),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          if (resumes.isEmpty)
                                            _buildEmptyResumeCard()
                                          else
                                            ...resumes.map(_buildResumeCard),
                                          if (activeResumeId != null) ...[
                                            const SizedBox(height: 12),
                                            _buildActiveResumeNotice(),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                // MOBILE: STACKED
                                _buildSectionTitle('Personal Information'),
                                const SizedBox(height: 12),
                                _buildInfoCard(
                                  icon: Icons.person_outline,
                                  title: 'Full Name',
                                  value: userProfile?['name'] ?? '',
                                  onEdit: _showEditNameDialog,
                                ),
                                _buildInfoCard(
                                  icon: Icons.email_outlined,
                                  title: 'Email Address',
                                  value:
                                      userProfile?['email'] ??
                                      currentUser?.email ??
                                      '',
                                ),
                                _buildInfoCard(
                                  icon: Icons.flag_outlined,
                                  title: 'Career Goal',
                                  value: userProfile?['careerGoal'] ?? '',
                                  onEdit: _showEditCareerGoalDialog,
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionTitle('My Resumes'),
                                    TextButton.icon(
                                      onPressed: _addResume,
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Add Resume'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (resumes.isEmpty)
                                  _buildEmptyResumeCard()
                                else
                                  ...resumes.map(_buildResumeCard),
                                if (activeResumeId != null) ...[
                                  const SizedBox(height: 12),
                                  _buildActiveResumeNotice(),
                                ],
                              ],

                              const SizedBox(height: 32),

                              // LOGOUT BUTTON
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _logout,
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    color: AppTheme.rose,
                                  ),
                                  label: const Text(
                                    'Log Out',
                                    style: TextStyle(
                                      color: AppTheme.rose,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFFECDD3),
                                    ),
                                    backgroundColor: const Color(0xFFFFF1F2),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
