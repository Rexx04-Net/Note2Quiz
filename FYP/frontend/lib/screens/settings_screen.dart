import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../state/app_settings_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.userEmail,
    required this.settingsController,
  });

  final String userEmail;
  final AppSettingsController settingsController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSendingFeedback = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('Please enter your feedback before sending.');
      return;
    }

    setState(() => _isSendingFeedback = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit-feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'email': widget.userEmail,
          'message': message,
          'language': widget.settingsController.outputLanguage,
          'theme_mode': widget.settingsController.themeMode.name,
        }),
      );

      if (response.statusCode == 200) {
        _feedbackController.clear();
        _showSnackBar('Thanks. Your feedback was sent successfully.');
      } else {
        _showSnackBar('Feedback could not be sent right now.');
      }
    } catch (_) {
      _showSnackBar('Network error while sending feedback.');
    } finally {
      if (mounted) setState(() => _isSendingFeedback = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        final settings = widget.settingsController;
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              _buildSectionCard(
                context,
                title: 'Appearance',
                subtitle: 'Switch the app between light and dark mode.',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildThemeChoice(
                      context: context,
                      label: 'Light mode',
                      icon: Icons.light_mode_outlined,
                      selected: settings.themeMode == ThemeMode.light,
                      onTap: () => settings.setThemeMode(ThemeMode.light),
                    ),
                    _buildThemeChoice(
                      context: context,
                      label: 'Dark mode',
                      icon: Icons.dark_mode_outlined,
                      selected: settings.themeMode == ThemeMode.dark,
                      onTap: () => settings.setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildSectionCard(
                context,
                title: 'Output language',
                subtitle:
                    'Choose the language for generated quizzes, flashcards, and reports.',
                child: DropdownButtonFormField<String>(
                  value: settings.outputLanguage,
                  dropdownColor: colors.surface,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                  ),
                  items: AppSettingsController.supportedLanguages
                      .map(
                        (language) => DropdownMenuItem<String>(
                          value: language,
                          child: Text(language),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settings.setOutputLanguage(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),
              _buildSectionCard(
                context,
                title: 'Send feedback',
                subtitle:
                    'Tell us what is working well or what should feel better in the app.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed in as ${widget.userEmail}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.subtleText,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _feedbackController,
                      minLines: 5,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        hintText: 'Share your feedback here...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSendingFeedback ? null : _submitFeedback,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: _isSendingFeedback
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _isSendingFeedback ? 'Sending...' : 'Send feedback',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildThemeChoice({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colors.primarySoft : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? scheme.primary : colors.mutedText),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? scheme.primary : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
