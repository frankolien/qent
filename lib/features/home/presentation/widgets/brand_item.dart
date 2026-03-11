import 'package:flutter/material.dart';

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
                color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isAll
                    ? Icon(
                        Icons.apps_rounded,
                        size: 22,
                        color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                      )
                    : _buildBrandLogo(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              brand,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandLogo() {
    final logoUrl = _brandLogos[brand];
    if (logoUrl == null) {
      return Text(
        brand.substring(0, 1),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
        ),
      );
    }

    return ColorFiltered(
      colorFilter: isSelected
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : const ColorFilter.mode(Color(0xFF1A1A1A), BlendMode.srcIn),
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
            color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}
