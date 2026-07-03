import 'package:hive/hive.dart';
import 'InstrumentMode.dart';

part 'InstrumentAccess.g.dart';

@HiveType(typeId: 1)
enum InstrumentAccess {
  @HiveField(0)
  liver,
  @HiveField(1)
  lung,
  @HiveField(2)
  kidney,
  @HiveField(3)
  bone,
  @HiveField(4)
  thyroid,
  @HiveField(5)
  endovenuos,
  @HiveField(6)
  breast,
  @HiveField(7)
  uterus,
}

extension InstrumentAccessExtension on InstrumentAccess {
  List<InstrumentMode> get supportedModes {
    switch (this) {
      case InstrumentAccess.liver:
        return [InstrumentMode.footSwitch, InstrumentMode.continuous];
      case InstrumentAccess.lung:
        return [InstrumentMode.footSwitch, InstrumentMode.continuous];
      case InstrumentAccess.kidney:
        return [InstrumentMode.continuous, InstrumentMode.footSwitch];
      case InstrumentAccess.bone:
        return [InstrumentMode.footSwitch, InstrumentMode.continuous];
      case InstrumentAccess.thyroid:
        return [InstrumentMode.footSwitch, InstrumentMode.continuous];
      case InstrumentAccess.endovenuos:
        return [InstrumentMode.endovascular];
      case InstrumentAccess.breast:
        return [InstrumentMode.footSwitch, InstrumentMode.continuous];
      case InstrumentAccess.uterus:
        return [InstrumentMode.footSwitch, InstrumentMode.continuous];
    }
  }
}
