import 'package:flutter/material.dart';

class BrandItem extends StatelessWidget {
  final String brand;

  const BrandItem({super.key, required this.brand});

  Widget _getBrandLogo(String brand) {
    // Placeholder for brand logos - you can replace with actual asset images
    switch (brand) {
      case 'Tesla':
        return Image.asset('assets/images/Tesla.png', width: 40, height: 40);
      case 'Lamborghini':
        return  Image.asset('assets/images/Lambo.png', width: 40, height: 40);
      case 'BMW':
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child:  Center(
            child: Image.asset('assets/images/Bmw.png', width: 40, height: 40),
          ),
        );
      case 'Ferrari':
        return Image.asset('assets/images/Ferrari.png', width: 40, height: 40);
      default:
        return const Icon(Icons.directions_car, color: Colors.white, size: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      margin: const EdgeInsets.only(right: 30),
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Center(child: _getBrandLogo(brand)),
    );
  }
}

