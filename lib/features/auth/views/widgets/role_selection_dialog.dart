import 'package:flutter/material.dart';
import '../../../../core/widgets/pig_icon.dart';
import 'role_card.dart';

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
            title: const Text('Welcome to PALAHI!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us who you are so we can set up your account:',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: RoleCard(
                        label: 'Farmer',
                        caption: 'Book stud pigs',
                        icon: const Icon(Icons.agriculture_outlined, size: 30),
                        selected: selectedRole == 'farmer',
                        onTap: () =>
                            setDialogState(() => selectedRole = 'farmer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RoleCard(
                        label: 'Breeder',
                        caption: 'Offer stud pigs',
                        icon: const PigIcon(size: 30),
                        selected: selectedRole == 'breeder',
                        onTap: () =>
                            setDialogState(() => selectedRole = 'breeder'),
                      ),
                    ),
                  ],
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
