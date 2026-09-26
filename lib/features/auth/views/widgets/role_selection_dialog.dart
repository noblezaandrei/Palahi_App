import 'package:flutter/material.dart';

/// Asks a user without a profile whether they're a farmer or a breeder.
/// Non-dismissible; resolves to 'farmer' or 'breeder' (null only if the
/// caller's widget went away).
Future<String?> showRoleSelectionDialog(BuildContext context) {
  String selectedRole = 'farmer';

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Welcome!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us who you are so we can set up your account:',
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: selectedRole,
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRole = value);
                    }
                  },
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        title: Text('Farmer'),
                        value: 'farmer',
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: Text('Breeder'),
                        value: 'breeder',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(selectedRole),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );
}
