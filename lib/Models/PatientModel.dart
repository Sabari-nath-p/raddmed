import 'package:hive/hive.dart';

part 'PatientModel.g.dart';

@HiveType(typeId: 3)
class PatientModel extends HiveObject {
  @HiveField(0)
  String id; // Internal unique id

  @HiveField(1)
  String patientId; // User-facing patient id (e.g. P10024)

  @HiveField(2)
  String name;

  @HiveField(3)
  String contactNumber;

  @HiveField(4)
  String consultingDoctor;

  @HiveField(5)
  String diagnosisArea;

  @HiveField(6)
  String gender;

  @HiveField(7)
  String age;

  @HiveField(8)
  String address;

  @HiveField(9)
  String note;

  @HiveField(10)
  String lastProcedureDate;

  PatientModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.contactNumber,
    required this.consultingDoctor,
    required this.diagnosisArea,
    required this.gender,
    required this.age,
    required this.address,
    required this.note,
    this.lastProcedureDate = '',
  });
}
