import 'package:hive/hive.dart';

part 'UserType.g.dart';

@HiveType(typeId: 0)
enum UserType {
  @HiveField(0)
  rootUser,
  @HiveField(1)
  admin,
  @HiveField(2)
  staff,
}
