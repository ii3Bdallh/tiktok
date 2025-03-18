import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tiktok_clone/constants.dart';
import 'package:tiktok_clone/models/user.dart' as model;
import 'package:tiktok_clone/views/screens/auth/login_screen.dart';
import 'package:tiktok_clone/views/screens/home_screen.dart';

class AuthController extends GetxController {
  static AuthController instance = Get.find();

  late Rx<User?> _user;
  late Rx<File?> _pickedImage; // تم التهيئة لاحقًا في onReady()

  File? get profilePhoto => _pickedImage.value;

  User get user => _user.value!; // تجنب null check بدون معالجة

  @override
  void onReady() {
    super.onReady();

    _user = Rx<User?>(firebaseAuth.currentUser);
    _user.bindStream(firebaseAuth.authStateChanges());
    ever(_user, _setInitialScreen);

    _pickedImage =
        Rx<File?>(null); // **تمت تهيئة `_pickedImage` لتجنب الأخطاء**
  }

  _setInitialScreen(User? user) {
    if (user == null) {
      Get.offAll(() => LoginScreen());
    } else {
      Get.offAll(() => const HomeScreen());
    }
  }

  void pickImage() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      _pickedImage.value = File(pickedImage.path);
      update(); // **تحديث الواجهة فورًا بعد اختيار الصورة**
      Get.snackbar('Profile Picture',
          'You have successfully selected your profile picture!');
    }
  }

  // **رفع الصورة إلى Firebase Storage**
  Future<String> _uploadToStorage(File image) async {
    Reference ref = firebaseStorage
        .ref()
        .child('profilePics')
        .child(firebaseAuth.currentUser!.uid);

    UploadTask uploadTask = ref.putFile(image);
    TaskSnapshot snap = await uploadTask;
    String downloadUrl = await snap.ref.getDownloadURL();
    return downloadUrl;
  }

  // **تسجيل المستخدم**
  void registerUser(
      String username, String email, String password, File? image) async {
    try {
      if (username.isNotEmpty &&
          email.isNotEmpty &&
          password.isNotEmpty &&
          image != null) {
        // إنشاء المستخدم في Firebase Authentication
        UserCredential cred = await firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // رفع الصورة إلى Firebase Storage والحصول على الرابط
        String downloadUrl = await _uploadToStorage(image);

        // إنشاء كائن المستخدم وتخزينه في Firestore
        model.User user = model.User(
          name: username,
          email: email,
          uid: cred.user!.uid,
          profilePhoto: downloadUrl,
        );

        await firestore
            .collection('users')
            .doc(cred.user!.uid)
            .set(user.toJson());
      } else {
        Get.snackbar('Error Creating Account', 'Please enter all the fields');
      }
    } catch (e) {
      Get.snackbar('Error Creating Account', e.toString());
    }
  }

  // **تسجيل الدخول**
  void loginUser(String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        await firebaseAuth.signInWithEmailAndPassword(
            email: email, password: password);
      } else {
        Get.snackbar('Error Logging in', 'Please enter all the fields');
      }
    } catch (e) {
      Get.snackbar('Error Logging in', e.toString());
    }
  }

  // **تسجيل الخروج**
  void signOut() async {
    await firebaseAuth.signOut();
  }
}
