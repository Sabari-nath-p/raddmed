// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HospitalModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HospitalModelAdapter extends TypeAdapter<HospitalModel> {
  @override
  final int typeId = 4;

  @override
  HospitalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HospitalModel(
      id: fields[0] as String,
      name: fields[1] as String,
      address: fields[2] as String,
      phone: fields[3] as String,
      website: fields[4] as String,
      logo: (fields[5] as List?)?.cast<int>(),
      authorizedBy: fields[6] as String? ?? '',
      // field 7 used to be Uint8List? in the old schema — if we read bytes
      // here from a legacy record, we simply ignore them and start fresh.
      signaturePath: fields[7] is String ? fields[7] as String : '',
    );
  }

  @override
  void write(BinaryWriter writer, HospitalModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.website)
      ..writeByte(5)
      ..write(obj.logo)
      ..writeByte(6)
      ..write(obj.authorizedBy)
      ..writeByte(7)
      ..write(obj.signaturePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HospitalModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
