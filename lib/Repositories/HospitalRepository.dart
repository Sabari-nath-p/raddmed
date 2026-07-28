import 'package:hive/hive.dart';
import '../Models/HospitalModel.dart';

class HospitalRepository {
  static const String boxName = 'hospitals';

  HospitalRepository._();

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<HospitalModel>(boxName);
    }
  }

  static Future<void> saveHospital(HospitalModel hospital) async {
    final box = Hive.box<HospitalModel>(boxName);
    await box.put(hospital.id, hospital);
  }

  static HospitalModel? getHospital(String id) {
    final box = Hive.box<HospitalModel>(boxName);
    return box.get(id);
  }

  static List<String> getAllHospitalIds() {
    final box = Hive.box<HospitalModel>(boxName);
    return box.keys.cast<String>().toList();
  }

  static Future<void> clearAllHospitals() async {
    final box = Hive.box<HospitalModel>(boxName);
    await box.clear();
  }
}
