enum AntennaType {
  coolTip1_5cm,
  coolTip2_0cm,
  coolTip2_5cm,
  coolTip3_0cm,
  coolTip3_5cm,
}

extension AntennaTypeExtension on AntennaType {
  String get displayName {
    switch (this) {
      case AntennaType.coolTip1_5cm:
        return 'RAAD CoolTip 17G';
      case AntennaType.coolTip2_0cm:
        return 'RAAD CoolTip 16G';
      case AntennaType.coolTip2_5cm:
        return 'RAAD CoolTip 14G';
      case AntennaType.coolTip3_0cm:
        return 'RAAD CoolTip 16G (3.0 cm)';
      case AntennaType.coolTip3_5cm:
        return 'RAAD CoolTip 17G (3.5 cm)';
    }
  }
}
