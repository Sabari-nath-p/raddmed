import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:raddmed/Screens/ActiveAblationScreen/ActiveAblationScreen.dart';
import 'package:raddmed/Screens/AuthenticationScreen/AuthenticationScreen.dart';
import 'package:raddmed/Screens/DashboardScreen/DashboardScreen.dart';
import 'package:raddmed/Screens/UserManagmentScreen/UserManagementScreen.dart';
import 'package:raddmed/Models/Enums/UserType.dart';
import 'package:raddmed/Models/Enums/InstrumentAccess.dart';
import 'package:raddmed/Models/UserModel.dart';
import 'package:raddmed/Models/PatientModel.dart';
import 'package:raddmed/Models/HospitalModel.dart';
import 'package:raddmed/Repositories/UserRepository.dart';
import 'package:raddmed/Repositories/PatientRepository.dart';
import 'package:raddmed/Repositories/HospitalRepository.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Models/ProcedureModel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(UserTypeAdapter());
  Hive.registerAdapter(InstrumentAccessAdapter());
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(PatientModelAdapter());
  Hive.registerAdapter(HospitalModelAdapter());
  Hive.registerAdapter(ProcedureModelAdapter());

  // Initialize repositories (opens box & seeds data)
  await UserRepository.init();
  await PatientRepository.init();
  await HospitalRepository.init();
  await ProcedureRepository.init();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthenticationScreen(),
    );
  }
}
