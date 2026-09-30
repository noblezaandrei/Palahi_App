import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/app_version_text.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(tr('Language')),
            subtitle: Text(appLanguage.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("Change Password"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text("Privacy Policy"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text("Terms & Conditions"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Terms & Conditions"),
                  content: const SingleChildScrollView(
                    child: Text(
                      "By using PALAHI, users agree to provide accurate information and use the application responsibly. Breeding transactions are the responsibility of both the farmer and breeder.",
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Version"),
            subtitle: AppVersionText(),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final picked = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Language')),
        children: [
          RadioGroup<AppLanguage>(
            groupValue: appLanguage,
            onChanged: (l) => Navigator.pop(context, l),
            child: Column(
              children: [
                for (final language in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: language,
                    title: Text(language.label),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              'The main farmer screens are translated so far; the rest '
              'stays in English for now.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await setAppLanguage(uid, picked).withNetworkTimeout();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Language not saved: ${friendlyError(e)}')),
      );
    }
  }
}
