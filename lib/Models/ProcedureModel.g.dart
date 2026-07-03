// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ProcedureModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProcedureModelAdapter extends TypeAdapter<ProcedureModel> {
  @override
  final int typeId = 5;

  @override
  ProcedureModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProcedureModel(
      id: fields[0] as String,
      patientId: fields[1] as String,
      patientName: fields[2] as String,
      category: fields[3] as String,
      mode: fields[4] as String,
      antenna: fields[5] as String,
      antennaSerialNumber: fields[6] as String,
      startTime: fields[7] as String,
      endTime: fields[8] as String,
      status: fields[9] as String,
      initiatedByUserId: fields[10] as String,
      initiatedByUserName: fields[11] as String,
      numberCycle: fields[12] as String?,
      procedureLog: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProcedureModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.patientName)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.mode)
      ..writeByte(5)
      ..write(obj.antenna)
      ..writeByte(6)
      ..write(obj.antennaSerialNumber)
      ..writeByte(7)
      ..write(obj.startTime)
      ..writeByte(8)
      ..write(obj.endTime)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.initiatedByUserId)
      ..writeByte(11)
      ..write(obj.initiatedByUserName)
      ..writeByte(12)
      ..write(obj.numberCycle)
      ..writeByte(13)
      ..write(obj.procedureLog);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcedureModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
