import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/colors.dart';

/// A farmer/breeder choice: a card that turns green when picked.
class RoleCard extends StatelessWidget {
  final String label;
  final String caption;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.label,
    required this.caption,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryBackground
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.cardBorder,
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textLight,
                      ),
                      child: icon,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textDark,
                      ),
                    ),
                    Text(
                      caption,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -6,
                  right: -2,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: selected ? 1 : 0,
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
