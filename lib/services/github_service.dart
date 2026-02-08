import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:skillsync_sp2/services/user_service.dart';

class GitHubService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  /// Check if the current user has GitHub linked as a provider.
  bool isGitHubLinked() {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'github.com');
  }

  /// Get the linked GitHub username from provider data.
  String? getLinkedGitHubUsername() {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final githubProvider = user.providerData
          .firstWhere((info) => info.providerId == 'github.com');
      return githubProvider.displayName;
    } catch (_) {
      return null;
    }
  }

  /// Link GitHub account via OAuth and persist data to Firestore.
  /// Returns the GitHub username on success.
  Future<String> linkGitHub() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final githubProvider = GithubAuthProvider();
    githubProvider.addScope('read:user');
    githubProvider.addScope('user:email');

    try {
      final userCredential = await user.linkWithProvider(githubProvider);

      final username = userCredential.additionalUserInfo?.username ?? '';
      final profile = userCredential.additionalUserInfo?.profile;
      final githubUrl = profile?['html_url'] as String? ??
          (username.isNotEmpty ? 'https://github.com/$username' : '');

      debugPrint('GitHub linked: username=$username, url=$githubUrl');

      await _userService.updateUserProfile({
        'githubUsername': username,
        'githubUrl': githubUrl,
        'githubLinked': true,
      });

      return username;
    } on FirebaseAuthException catch (e) {
      debugPrint('GitHub link error: ${e.code} - ${e.message}');
      if (e.code == 'credential-already-in-use') {
        throw Exception(
          'This GitHub account is already linked to another SkillSync user. '
          'Please use a different GitHub account.',
        );
      } else if (e.code == 'provider-already-linked') {
        throw Exception('A GitHub account is already linked to your profile.');
      } else if (e.code == 'popup-closed-by-user' ||
          e.code == 'web-context-cancelled') {
        throw Exception('GitHub sign-in was cancelled.');
      }
      rethrow;
    }
  }

  /// Unlink GitHub from the current user and clear Firestore data.
  Future<void> unlinkGitHub() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    await user.unlink('github.com');

    await _userService.updateUserProfile({
      'githubUsername': '',
      'githubUrl': '',
      'githubLinked': false,
    });
  }
}
