import 'package:flutter/material.dart';
import 'package:qent/core/theme/app_theme.dart';

class BrandItem extends StatelessWidget {
  final String brand;
  final bool isSelected;
  final VoidCallback? onTap;

  const BrandItem({
    super.key,
    required this.brand,
    this.isSelected = false,
    this.onTap,
  });

  static const Map<String, String> _brandLogos = {
    'Toyota': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Toyota.svg/200px-Toyota.svg.png',
    'Honda': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/76/Honda_logo.svg/200px-Honda_logo.svg.png',
    'Mercedes': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Mercedes-Logo.svg/200px-Mercedes-Logo.svg.png',
    'Lexus': 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d1/Lexus_division_emblem.svg/200px-Lexus_division_emblem.svg.png',
    'Range Rover': 'https://www.carlogos.org/logo/Land-Rover-logo-2011-1920x1080.png',
  };

  @override
  Widget build(BuildContext context) {
    final isAll = brand == 'All';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? (context.isDark ? const Color(0xFF22C55E) : const Color(0xFF1A1A1A))
                    : context.bgSecondary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? (context.isDark ? const Color(0xFF22C55E) : const Color(0xFF1A1A1A))
                      : context.borderColor,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isAll
                    ? Icon(
                        Icons.apps_rounded,
                        size: 22,
                        color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.textPrimary,
                      )
                    : _buildBrandLogo(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              brand,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? context.textPrimary : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandLogo(BuildContext context) {
    final logoUrl = _brandLogos[brand];
    final selectedColor = context.isDark ? Colors.black : Colors.white;
    final unselectedColor = context.textPrimary;

    if (logoUrl == null) {
      return Text(
        brand.substring(0, 1),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isSelected ? selectedColor : unselectedColor,
        ),
      );
    }

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        isSelected ? selectedColor : unselectedColor,
        BlendMode.srcIn,
      ),
      child: Image.network(
        logoUrl,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          brand.substring(0, 1),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isSelected ? selectedColor : unselectedColor,
          ),
        ),
      ),
    );
  }
}
