import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/colors.dart';

// A pig face in the style of the app logo (pink pig, dark eyes, rosy
// snout), drawn on a 48x48 grid.
const _pigFace = '''
<path d="M7 9 L18 13 L10 22 Z" fill="#F7B6B6" stroke="#F7B6B6" stroke-width="3" stroke-linejoin="round"/>
<path d="M41 9 L30 13 L38 22 Z" fill="#F7B6B6" stroke="#F7B6B6" stroke-width="3" stroke-linejoin="round"/>
<path d="M10 12 L16 14 L11.5 19 Z" fill="#EC8E8E"/>
<path d="M38 12 L32 14 L36.5 19 Z" fill="#EC8E8E"/>
<ellipse cx="24" cy="26" rx="17" ry="15" fill="#F9C6C6"/>
<circle cx="17" cy="22.5" r="3.2" fill="#3E2C28"/>
<circle cx="31" cy="22.5" r="3.2" fill="#3E2C28"/>
<circle cx="18" cy="21.4" r="1.1" fill="#FFFFFF"/>
<circle cx="32" cy="21.4" r="1.1" fill="#FFFFFF"/>
<ellipse cx="24" cy="31.5" rx="7.5" ry="5.2" fill="#EF9A9A"/>
<ellipse cx="21.3" cy="31.5" rx="1.3" ry="2" fill="#3E2C28"/>
<ellipse cx="26.7" cy="31.5" rx="1.3" ry="2" fill="#3E2C28"/>
''';

const _plusBadge = '''
<circle cx="38" cy="38" r="9" fill="#2E7D32" stroke="#FFFFFF" stroke-width="2.5"/>
<path d="M38 33.5 V42.5 M33.5 38 H42.5" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round"/>
''';

/// The app's pig icon. [withPlus] adds a green "+" badge, for adding a
/// stud pig.
class PigIcon extends StatelessWidget {
  final double size;
  final bool withPlus;

  const PigIcon({super.key, this.size = 24, this.withPlus = false});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
      '$_pigFace${withPlus ? _plusBadge : ''}</svg>',
      width: size,
      height: size,
    );
  }
}

/// Stand-in for a stud pig without a photo (or whose photo failed to load).
class PigPlaceholder extends StatelessWidget {
  final double iconSize;

  const PigPlaceholder({super.key, this.iconSize = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryBackground,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: Opacity(opacity: 0.85, child: PigIcon(size: iconSize)),
    );
  }
}
