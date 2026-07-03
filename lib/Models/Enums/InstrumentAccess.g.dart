// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'InstrumentAccess.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstrumentAccessAdapter extends TypeAdapter<InstrumentAccess> {
  @override
  final int typeId = 1;

  @override
  InstrumentAccess read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return InstrumentAccess.liver;
      case 1:
        return InstrumentAccess.lung;
      case 2:
        return InstrumentAccess.kidney;
      case 3:
        return InstrumentAccess.bone;
      case 4:
        return InstrumentAccess.thyroid;
      case 5:
        return InstrumentAccess.endovenuos;
      case 6:
        return InstrumentAccess.breast;
      case 7:
        return InstrumentAccess.uterus;
      default:
        return InstrumentAccess.liver;
    }
  }

  @override
  void write(BinaryWriter writer, InstrumentAccess obj) {
    switch (obj) {
      case InstrumentAccess.liver:
        writer.writeByte(0);
        break;
      case InstrumentAccess.lung:
        writer.writeByte(1);
        break;
      case InstrumentAccess.kidney:
        writer.writeByte(2);
        break;
      case InstrumentAccess.bone:
        writer.writeByte(3);
        break;
      case InstrumentAccess.thyroid:
        writer.writeByte(4);
        break;
      case InstrumentAccess.endovenuos:
        writer.writeByte(5);
        break;
      case InstrumentAccess.breast:
        writer.writeByte(6);
        break;
      case InstrumentAccess.uterus:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstrumentAccessAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
