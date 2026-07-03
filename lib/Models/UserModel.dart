import 'package:hive/hive.dart';
import 'Enums/UserType.dart';
import 'Enums/InstrumentAccess.dart';

part 'UserModel.g.dart';

@HiveType(typeId: 2)
class UserModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String userid;

  @HiveField(3)
  String password;

  @HiveField(4)
  UserType userType;

  @HiveField(5)
  List<InstrumentAccess> accessInstruments;

  @HiveField(6)
  String data;

  @HiveField(7)
  DateTime? expiryDate;

  UserModel({
    required this.id,
    required this.name,
    required this.userid,
    required this.password,
    required this.userType,
    required this.accessInstruments,
    this.data = '',
    this.expiryDate,
  });
}
