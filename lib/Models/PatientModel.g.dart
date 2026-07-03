// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PatientModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatientModelAdapter extends TypeAdapter<PatientModel> {
  @override
  final int typeId = 3;

  @override
  PatientModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PatientModel(
      id: fields[0] as String,
      patientId: fields[1] as String,
      name: fields[2] as String,
      contactNumber: fields[3] as String,
      consultingDoctor: fields[4] as String,
      diagnosisArea: fields[5] as String,
      gender: fields[6] as String,
      age: fields[7] as String,
      address: fields[8] as String,
      note: fields[9] as String,
      lastProcedureDate: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PatientModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.contactNumber)
      ..writeByte(4)
      ..write(obj.consultingDoctor)
      ..writeByte(5)
      ..write(obj.diagnosisArea)
      ..writeByte(6)
      ..write(obj.gender)
      ..writeByte(7)
      ..write(obj.age)
      ..writeByte(8)
      ..write(obj.address)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.lastProcedureDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
