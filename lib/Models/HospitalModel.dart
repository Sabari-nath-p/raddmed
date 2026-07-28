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
  final List<int>? logo;

  @HiveField(6)
  final String authorizedBy;

  /// Absolute path to the signature image file saved in the app-support
  /// directory. Empty string means no signature has been configured.
  @HiveField(7)
  final String signaturePath;

  HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.website,
    this.logo,
    this.authorizedBy = '',
    this.signaturePath = '',
  });
}
