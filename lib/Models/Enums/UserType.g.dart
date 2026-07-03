// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'UserType.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserTypeAdapter extends TypeAdapter<UserType> {
  @override
  final int typeId = 0;

  @override
  UserType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserType.rootUser;
      case 1:
        return UserType.admin;
      case 2:
        return UserType.staff;
      default:
        return UserType.rootUser;
    }
  }

  @override
  void write(BinaryWriter writer, UserType obj) {
    switch (obj) {
      case UserType.rootUser:
        writer.writeByte(0);
        break;
      case UserType.admin:
        writer.writeByte(1);
        break;
      case UserType.staff:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
