import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'HospitalModel.g.dart';

@HiveType(typeId: 4)
class HospitalModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String address;

  @HiveField(3)
  final String phone;

  @HiveField(4)
  final String website;

  @HiveField(5)
  final Uint8List? logo;

  HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.website,
    this.logo,
  });
}
