import 'package:hive/hive.dart';
import '../Models/UserModel.dart';
import '../Models/Enums/UserType.dart';
import '../Models/Enums/InstrumentAccess.dart';
import 'package:flutter/foundation.dart';

class UserRepository {
  static const String boxName = 'users';

  // Make constructor private to prevent instantiation
  UserRepository._();

  static Future<void> init() async {
    // Open the Hive box
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<UserModel>(boxName);
    }

    // Seed default data if empty
    final box = Hive.box<UserModel>(boxName);
    if (box.isEmpty) {
      debugPrint('Seeding default users...');

      await addUser(
        UserModel(
          id: 'root1',
          name: 'Super Root',
          userid: 'root',
          password: 'rootpassword',
          userType: UserType.rootUser,
          accessInstruments: [
            InstrumentAccess.liver,
            InstrumentAccess.lung,
            InstrumentAccess.kidney,
          ],
          data: 'Super Root Account',
        ),
      );
    }
  }

  static Future<void> addUser(UserModel user) async {
    final box = Hive.box<UserModel>(boxName);
    await box.put(user.userid, user);
  }

  static Future<UserModel?> getUser(String userid) async {
    final box = Hive.box<UserModel>(boxName);
    return box.get(userid);
  }

  static Future<List<UserModel>> getAllUsers() async {
    final box = Hive.box<UserModel>(boxName);
    return box.values.toList();
  }

  static Future<void> updateUser(UserModel user) async {
    final box = Hive.box<UserModel>(boxName);
    await box.put(user.userid, user);
  }

  static Future<void> deleteUser(String userid) async {
    final box = Hive.box<UserModel>(boxName);
    await box.delete(userid);
  }

  static Future<void> clearAllUsers() async {
    final box = Hive.box<UserModel>(boxName);
    await box.clear();
    await init();
  }

  static Future<UserModel?> authenticate(String userid, String password) async {
    final user = await getUser(userid);
    if (user != null && user.password == password) {
      return user;
    }
    return null;
  }
}
