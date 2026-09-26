import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed app's version (from pubspec.yaml's `version:`), so the
/// About and Settings screens can't drift out of date like the hard-coded
/// "1.0.0" did.
class AppVersionText extends StatelessWidget {
  final String prefix;
  final TextStyle? style;

  const AppVersionText({super.key, this.prefix = '', this.style});

  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        return Text(version.isEmpty ? '' : '$prefix$version', style: style);
      },
    );
  }
}
