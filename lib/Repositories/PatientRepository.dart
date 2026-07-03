import 'package:hive/hive.dart';
import '../Models/PatientModel.dart';
import 'package:flutter/foundation.dart';

class PatientRepository {
  static const String boxName = 'patients';

  PatientRepository._();

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<PatientModel>(boxName);
    }

    final box = Hive.box<PatientModel>(boxName);
    if (box.isEmpty) {
      debugPrint('Seeding default patients...');
      await addPatient(
        PatientModel(
          id: '1',
          patientId: '1',
          name: 'Robert Johnson',
          contactNumber: '+1 987 654 3210',
          consultingDoctor: 'Dr. John Smith',
          diagnosisArea: 'LIVER',
          gender: 'Male',
          age: '58',
          address: '123 Medical Street, New York, NY 10001, USA',
          note: 'Patient responding well to treatment. Continue monitoring.',
          lastProcedureDate: '20 May 2024',
        ),
      );
    }
  }

  static Future<void> addPatient(PatientModel patient) async {
    final box = Hive.box<PatientModel>(boxName);
    await box.put(patient.id, patient);
  }

  static Future<void> updatePatient(PatientModel patient) async {
    final box = Hive.box<PatientModel>(boxName);
    await box.put(
      patient.id,
      patient,
    ); // Hive uses same method for insert/update
  }

  static List<PatientModel> getAllPatients() {
    final box = Hive.box<PatientModel>(boxName);
    return box.values.toList();
  }

  static Future<void> deletePatient(String id) async {
    final box = Hive.box<PatientModel>(boxName);
    await box.delete(id);
  }

  static String generateNextPatientId() {
    final patients = getAllPatients();
    if (patients.isEmpty) {
      return '1';
    }
    int maxId = 0;
    for (var patient in patients) {
      final idStr = patient.patientId.replaceAll(RegExp(r'[^0-9]'), '');
      final id = int.tryParse(idStr);
      if (id != null && id > maxId) {
        maxId = id;
      }
    }
    return (maxId + 1).toString();
  }

  static Future<void> clearAllPatients() async {
    final box = Hive.box<PatientModel>(boxName);
    await box.clear();
  }
}
