import 'package:flutter_riverpod/flutter_riverpod.dart';

// Static brand lists (no Firestore dependency)
final regularBrandsProvider = Provider<List<String>>((ref) {
  return [
    'Toyota',
    'Honda',
    'Hyundai',
    'Kia',
    'Nissan',
    'Mazda',
    'Volkswagen',
    'Ford',
    'Chevrolet',
    'Peugeot',
    'Suzuki',
    'Mitsubishi',
  ];
});

final luxuryBrandsProvider = Provider<List<String>>((ref) {
  return [
    'Mercedes-Benz',
    'BMW',
    'Audi',
    'Lexus',
    'Range Rover',
    'Porsche',
    'Jaguar',
    'Bentley',
    'Rolls-Royce',
    'Tesla',
    'Maserati',
    'Infiniti',
  ];
});

// Static model lists per brand
final modelsProvider = Provider.family<List<String>, String>((ref, brandName) {
  final models = <String, List<String>>{
    'Toyota': ['Camry', 'Corolla', 'RAV4', 'Highlander', 'Land Cruiser', 'Hilux', 'Avalon', 'Venza'],
    'Honda': ['Civic', 'Accord', 'CR-V', 'HR-V', 'Pilot', 'Fit'],
    'Hyundai': ['Elantra', 'Sonata', 'Tucson', 'Santa Fe', 'Kona', 'Palisade'],
    'Kia': ['Sportage', 'Sorento', 'Seltos', 'Forte', 'K5', 'Telluride'],
    'Nissan': ['Altima', 'Sentra', 'Rogue', 'Pathfinder', 'Murano', 'Kicks'],
    'Mazda': ['CX-5', 'CX-9', 'Mazda3', 'Mazda6', 'CX-30'],
    'Volkswagen': ['Golf', 'Passat', 'Tiguan', 'Atlas', 'Jetta', 'Touareg'],
    'Ford': ['Explorer', 'Escape', 'F-150', 'Mustang', 'Edge', 'Bronco'],
    'Chevrolet': ['Malibu', 'Equinox', 'Tahoe', 'Silverado', 'Blazer', 'Traverse'],
    'Peugeot': ['208', '308', '508', '2008', '3008', '5008'],
    'Suzuki': ['Swift', 'Vitara', 'Jimny', 'S-Cross', 'Baleno'],
    'Mitsubishi': ['Outlander', 'Eclipse Cross', 'ASX', 'Pajero', 'L200'],
    'Mercedes-Benz': ['C-Class', 'E-Class', 'S-Class', 'GLC', 'GLE', 'AMG GT', 'A-Class', 'G-Wagon'],
    'BMW': ['3 Series', '5 Series', '7 Series', 'X3', 'X5', 'X7', 'iX', 'M4'],
    'Audi': ['A4', 'A6', 'A8', 'Q5', 'Q7', 'Q8', 'e-tron', 'RS7'],
    'Lexus': ['ES', 'IS', 'RX', 'NX', 'LX', 'GX', 'LC', 'LS'],
    'Range Rover': ['Sport', 'Velar', 'Evoque', 'Defender', 'Discovery', 'Vogue'],
    'Porsche': ['Cayenne', 'Macan', '911', 'Panamera', 'Taycan', 'Cayman'],
    'Jaguar': ['F-Pace', 'E-Pace', 'XE', 'XF', 'F-Type', 'I-Pace'],
    'Bentley': ['Continental GT', 'Bentayga', 'Flying Spur'],
    'Rolls-Royce': ['Ghost', 'Phantom', 'Cullinan', 'Wraith', 'Dawn'],
    'Tesla': ['Model 3', 'Model S', 'Model X', 'Model Y', 'Cybertruck'],
    'Maserati': ['Ghibli', 'Levante', 'Quattroporte', 'MC20', 'Grecale'],
    'Infiniti': ['Q50', 'Q60', 'QX50', 'QX60', 'QX80'],
  };
  return models[brandName] ?? [];
});
