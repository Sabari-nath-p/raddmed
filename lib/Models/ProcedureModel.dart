import 'package:hive/hive.dart';

part 'ProcedureModel.g.dart';

@HiveType(typeId: 5)
class ProcedureModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String patientId;

  @HiveField(2)
  String patientName;

  @HiveField(3)
  String category;

  @HiveField(4)
  String mode;

  @HiveField(5)
  String antenna;

  @HiveField(6)
  String antennaSerialNumber;

  @HiveField(7)
  String startTime;

  @HiveField(8)
  String endTime;

  @HiveField(9)
  String status;

  @HiveField(10)
  String initiatedByUserId;

  @HiveField(11)
  String initiatedByUserName;

  @HiveField(12)
  String? numberCycle;

  @HiveField(13)
  String? procedureLog;

  ProcedureModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.category,
    required this.mode,
    required this.antenna,
    required this.antennaSerialNumber,
    required this.startTime,
    this.endTime = '',
    required this.status,
    required this.initiatedByUserId,
    required this.initiatedByUserName,
    this.numberCycle,
    this.procedureLog,
  });
}
