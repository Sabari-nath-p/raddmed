import 'package:hive/hive.dart';
import '../Models/ProcedureModel.dart';

class ProcedureRepository {
  static const String boxName = 'procedures';

  ProcedureRepository._();

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<ProcedureModel>(boxName);
    }
  }

  static Future<void> addProcedure(ProcedureModel procedure) async {
    final box = Hive.box<ProcedureModel>(boxName);
    await box.put(procedure.id, procedure);
  }

  static Future<void> updateProcedure(ProcedureModel procedure) async {
    final box = Hive.box<ProcedureModel>(boxName);
    await box.put(procedure.id, procedure);
  }

  static List<ProcedureModel> getAllProcedures() {
    final box = Hive.box<ProcedureModel>(boxName);
    return box.values.toList();
  }

  static List<ProcedureModel> getProceduresForPatient(String patientId) {
    final box = Hive.box<ProcedureModel>(boxName);
    return box.values.where((p) => p.patientId == patientId).toList();
  }

  static Future<void> deleteProcedure(String id) async {
    final box = Hive.box<ProcedureModel>(boxName);
    await box.delete(id);
  }

  static Future<void> clearAllProcedures() async {
    final box = Hive.box<ProcedureModel>(boxName);
    await box.clear();
  }
}
