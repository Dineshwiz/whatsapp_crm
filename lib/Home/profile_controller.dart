import 'package:get/get.dart';

class UserController extends GetxController {
  // Reactive map holding the logged-in user's Firestore data
  final Rx<Map<String, dynamic>> userData = Rx<Map<String, dynamic>>({});

  // Convenience getters
  String get firstName => userData.value['first_name']?.toString() ?? '';
  String get lastName  => userData.value['last_name']?.toString()  ?? '';
  String get fullName  => '${firstName} ${lastName}'.trim();
  String get email     => userData.value['email']?.toString()       ?? '';
  String get userName  => userData.value['user_name']?.toString()   ?? '';
  String get phone     => userData.value['phone_number']?.toString() ?? '';
  String get userRole  => userData.value['user_role']?.toString()   ?? '';
  String get docId     => userData.value['doc_id']?.toString()      ?? '';

  void setUser(Map<String, dynamic> data) {
    userData.value = Map<String, dynamic>.from(data);
  }

  void clearUser() {
    userData.value = {};
  }
}