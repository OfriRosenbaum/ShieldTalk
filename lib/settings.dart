import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shield_talk/util.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool) updateThemeCallback;

  const SettingsPage({super.key, required this.updateThemeCallback});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDarkThemeEnabled = false;
  types.User? _user;

  void setStateCallback(types.User user) {
    _user = user;
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = isDarkThemeEnabled ? ThemeData.dark() : ThemeData.light();
    return Theme(
        data: themeData,
        // ignore: unnecessary_null_comparison
        child: _user == null
            ? const Center(child: CircularProgressIndicator())
            : Scaffold(
                appBar: AppBar(
                  title: const Text('Settings'),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: Column(
                      children: <Widget>[
                        GestureDetector(
                          onTap: _changePicture,
                          child: ClipOval(child: buildAvatar(_user!, 128)),
                        ),
                        const SizedBox(
                          height: 16,
                          width: 16,
                        ),
                        Text('User ID: ${FirebaseChatCore.instance.firebaseUser!.uid}'),
                        const SizedBox(
                          height: 32,
                          width: 32,
                        ),
                        themeSwitcherBuilder(),
                        const SizedBox(
                          height: 32,
                          width: 32,
                        ),
                        ElevatedButton(
                            onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ProfilePage(
                                      user: _user!,
                                      theme: themeData,
                                      callback: setStateCallback,
                                    ),
                                  ),
                                ),
                            child: const Text('Profile')),
                        const SizedBox.square(dimension: 16),
                        ElevatedButton(
                            onPressed: () {
                              FirebaseAuth.instance.signOut();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Sign Out')),
                      ],
                    ),
                  ),
                ),
              ));
  }

  //Creates a switch widget to toggle between light and dark theme.
  Row themeSwitcherBuilder() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Light Theme',
          style: TextStyle(fontSize: 20),
        ),
        Switch(
            value: isDarkThemeEnabled,
            onChanged: (value) {
              _saveThemePreference(value);
            }),
        const Text(
          'Dark Theme',
          style: TextStyle(fontSize: 20),
        ),
      ],
    );
  }

  // Method to save theme preference to Shared Preferences.
  Future<void> _saveThemePreference(bool value) async {
    if (!mounted) return;
    setState(() {
      isDarkThemeEnabled = value;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkThemeEnabled', value);
    widget.updateThemeCallback(value);
  }

  // Method to load theme preference from Shared Preferences.
  Future<void> _loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isDarkThemeEnabled = prefs.getBool('isDarkThemeEnabled') ?? false;
    });
  }

  //Loads the current firebase user.
  Future<void> _loadUser() async {
    _user = await getFirestoreUser(getFCC().firebaseUser);
    if (!mounted) return;
    setState(() {});
  }

  //Image picker to change profile picture for the user.
  Future<void> _changePicture() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      try {
        final croppedFile = await ImageCropper.platform.cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          maxWidth: 1440,
          compressQuality: 70,
        );
        FirebaseChatCore fcc = FirebaseChatCore.instance;
        FirebaseFirestore firestore = fcc.getFirebaseFirestore();
        User? user = FirebaseChatCore.instance.firebaseUser!;
        String name = '${user.uid}_${pickedFile.name}';
        if (croppedFile != null) {
          Uint8List bytes = await croppedFile.readAsBytes();
          final reference = FirebaseStorage.instance.ref(name);
          await reference.putData(bytes);
          final uri = await reference.getDownloadURL();
          firestore.collection(fcc.config.usersCollectionName).doc(user.uid).update({'imageUrl': uri});
          _user = await getFirestoreUser(getFCC().firebaseUser);
          if (!mounted) return;
          setState(() {});
        }
      } catch (e) {
        developer.log('Error updating image $e');
      }
    }
  }
}

// ignore: must_be_immutable
class ProfilePage extends StatefulWidget {
  final ThemeData theme;
  types.User user;
  final Function(types.User) callback;

  ProfilePage({super.key, required this.theme, required this.user, required this.callback});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  //Image picker to change profile picture for the user.
  Future<void> _changePicture() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      try {
        final croppedFile = await ImageCropper.platform.cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          maxWidth: 1440,
          compressQuality: 70,
        );
        FirebaseChatCore fcc = FirebaseChatCore.instance;
        FirebaseFirestore firestore = fcc.getFirebaseFirestore();
        User user = FirebaseChatCore.instance.firebaseUser!;
        String name = '${user.uid}_${pickedFile.name}';
        if (croppedFile != null) {
          Uint8List bytes = await croppedFile.readAsBytes();
          final reference = FirebaseStorage.instance.ref(name);
          await reference.putData(bytes);
          final uri = await reference.getDownloadURL();
          firestore.collection(fcc.config.usersCollectionName).doc(user.uid).update({'imageUrl': uri});
          widget.user = await getFirestoreUser(getFCC().firebaseUser);
          if (!mounted) return;
          setState(() {});
          widget.callback(await getFirestoreUser(user));
        }
      } catch (e) {
        developer.log('Error updating image $e');
      }
    }
  }

  //Modal sheet that lets the user change its first or last name.
  void editName(String field) {
    bool editable = true;
    final controller = InputTextFieldController();
    controller.text = field == 'first' ? widget.user.firstName! : widget.user.lastName!;
    showModalBottomSheet(
        backgroundColor: widget.theme == ThemeData.dark() ? Colors.grey[900] : Colors.white,
        context: context,
        isScrollControlled: true,
        builder: (BuildContext builder) {
          return StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox.square(dimension: 16),
                  Row(
                    children: [
                      const SizedBox.square(dimension: 16),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(fontSize: 20, color: Colors.blue),
                          maxLength: 14,
                          autofillHints:
                              field == 'first' ? const [AutofillHints.givenName] : const [AutofillHints.familyName],
                          // autofocus: true,
                          controller: controller,
                          decoration: InputDecoration(
                            labelStyle: const TextStyle(fontSize: 20, color: Colors.blue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue), // Border color when focused
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue), // Border color when not focused
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            counterStyle: const TextStyle(fontSize: 8, color: Colors.blue),
                            labelText: '${field[0].toUpperCase()}${field.substring(1)} Name',
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.blue,
                              ),
                              onPressed: () => controller.clear(),
                            ),
                          ),
                          keyboardType: TextInputType.name,
                          readOnly: !editable,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox.square(dimension: 16),
                    ],
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    const SizedBox.square(dimension: 16),
                    TextButton(
                      onPressed: editable
                          ? () {
                              Navigator.of(context).pop();
                            }
                          : () => {},
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: editable
                          ? () async {
                              setState(() {
                                editable = false;
                              });
                              String text = controller.value.text.trim();
                              Navigator.of(context).pop();
                              DocumentReference docRef = FirebaseFirestore.instance
                                  .collection(FirebaseChatCore.instance.config.usersCollectionName)
                                  .doc(FirebaseChatCore.instance.firebaseUser!.uid);
                              await docRef.update({field == 'first' ? 'firstName' : 'lastName': text});
                              field == 'first'
                                  ? widget.user = widget.user.copyWith(firstName: text)
                                  : widget.user = widget.user.copyWith(lastName: text);
                              if (!mounted) return;
                              setState(() {
                                editable = true;
                              });
                            }
                          : () => {},
                      child: const Text('Save'),
                    ),
                  ]),
                ],
              ),
            );
          });
        });
  }

  //Modal sheet that lets the user change its email.
  void editEmail() {
    final emailController = InputTextFieldController();
    final passwordController = InputTextFieldController();
    bool passwordVisible = false;
    bool editable = true;
    FirebaseAuth auth = FirebaseAuth.instance;
    User user = auth.currentUser!;
    emailController.text = user.email!;
    showModalBottomSheet(
        backgroundColor: widget.theme == ThemeData.dark() ? Colors.grey[900] : Colors.white,
        context: context,
        isScrollControlled: true,
        builder: (BuildContext builder) {
          return StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                top: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(fontSize: 20, color: Colors.blue),
                          autofillHints: const [AutofillHints.email],
                          // autofocus: true,
                          controller: emailController,
                          decoration: InputDecoration(
                            labelStyle: const TextStyle(fontSize: 20, color: Colors.blue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue), // Border color when focused
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue), // Border color when not focused
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            counterStyle: const TextStyle(fontSize: 8, color: Colors.blue),
                            labelText: 'Email',
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.blue,
                              ),
                              onPressed: () => emailController.clear(),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          readOnly: !editable,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox.square(dimension: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(fontSize: 20, color: Colors.blue),
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelStyle: const TextStyle(fontSize: 20, color: Colors.blue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            counterStyle: const TextStyle(fontSize: 8, color: Colors.blue),
                            labelText: 'Confirm Password',
                            suffixIcon: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.blue),
                                  onPressed: () => passwordController.clear(),
                                ),
                                IconButton(
                                  icon: Icon(
                                    passwordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() {
                                      passwordVisible = !passwordVisible;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: !passwordVisible,
                          readOnly: !editable,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                    ],
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: editable
                          ? () {
                              Navigator.of(context).pop();
                            }
                          : () => {},
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: editable
                          ? () async {
                              setState(() {
                                editable = false;
                              });
                              try {
                                AuthCredential credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: passwordController.text,
                                );
                                await user.reauthenticateWithCredential(credential);
                                await user.updateEmail(emailController.value.text);
                                await user.sendEmailVerification();
                                if (!mounted) return;
                                widget.callback(await getFirestoreUser(user));
                                setState(() {});
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                Fluttertoast.showToast(
                                    msg: 'Email changed successfully', toastLength: Toast.LENGTH_LONG);
                              } catch (e) {
                                if (e is FirebaseAuthException) {
                                  switch (e.code) {
                                    case 'invalid-email':
                                      Fluttertoast.showToast(msg: 'Invalid email', toastLength: Toast.LENGTH_LONG);
                                      break;
                                    case 'email-already-in-use':
                                      Fluttertoast.showToast(
                                          msg: 'Email already in use', toastLength: Toast.LENGTH_LONG);
                                      break;
                                    case 'wrong-password':
                                      Fluttertoast.showToast(msg: 'Wrong password', toastLength: Toast.LENGTH_LONG);
                                      break;
                                    default:
                                      Fluttertoast.showToast(
                                          msg: 'An error has occurred, please try again',
                                          toastLength: Toast.LENGTH_LONG);
                                      developer.log('$e');
                                  }
                                }
                                developer.log('$e');
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    editable = true;
                                  });
                                }
                              }
                            }
                          : () => {},
                      child: const Text('Save'),
                    ),
                  ]),
                ],
              ),
            );
          });
        });
  }

  //Modal sheet that lets the user change its password.
  void editPassword() {
    final newPasswordController = InputTextFieldController();
    final oldPasswordController = InputTextFieldController();
    bool newPasswordVisible = false;
    bool oldPasswordVisible = false;
    bool editable = true;
    FirebaseAuth auth = FirebaseAuth.instance;
    User user = auth.currentUser!;
    showModalBottomSheet(
        backgroundColor: widget.theme == ThemeData.dark() ? Colors.grey[900] : Colors.white,
        context: context,
        isScrollControlled: true,
        builder: (BuildContext builder) {
          return StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                top: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(fontSize: 20, color: Colors.blue),
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          controller: newPasswordController,
                          decoration: InputDecoration(
                            labelStyle: const TextStyle(fontSize: 20, color: Colors.blue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            counterStyle: const TextStyle(fontSize: 8, color: Colors.blue),
                            labelText: 'New Password',
                            suffixIcon: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.blue),
                                  onPressed: () => newPasswordController.clear(),
                                ),
                                IconButton(
                                  icon: Icon(
                                    newPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() {
                                      newPasswordVisible = !newPasswordVisible;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: !newPasswordVisible,
                          readOnly: !editable,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox.square(dimension: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(fontSize: 20, color: Colors.blue),
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          controller: oldPasswordController,
                          decoration: InputDecoration(
                            labelStyle: const TextStyle(fontSize: 20, color: Colors.blue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            counterStyle: const TextStyle(fontSize: 8, color: Colors.blue),
                            labelText: 'Old Password',
                            suffixIcon: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.blue),
                                  onPressed: () => oldPasswordController.clear(),
                                ),
                                IconButton(
                                  icon: Icon(
                                    oldPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      oldPasswordVisible = !oldPasswordVisible;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: !oldPasswordVisible,
                          readOnly: !editable,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                    ],
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: editable
                          ? () {
                              Navigator.of(context).pop();
                            }
                          : () => {},
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: editable
                          ? () async {
                              setState(() {
                                editable = false;
                              });
                              try {
                                AuthCredential credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: oldPasswordController.value.text,
                                );
                                await user.reauthenticateWithCredential(credential);
                                await user.updatePassword(newPasswordController.value.text);
                                if (!mounted) return;
                                widget.callback(await getFirestoreUser(user));
                                setState(() {});
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                Fluttertoast.showToast(
                                    msg: 'Password changed successfully', toastLength: Toast.LENGTH_LONG);
                              } catch (e) {
                                if (e is FirebaseAuthException) {
                                  switch (e.code) {
                                    case 'invalid-credentials':
                                      Fluttertoast.showToast(msg: 'Wrong password', toastLength: Toast.LENGTH_LONG);
                                      break;
                                    case 'wrong-password':
                                      Fluttertoast.showToast(msg: 'Wrong password', toastLength: Toast.LENGTH_LONG);
                                      break;
                                    default:
                                      Fluttertoast.showToast(
                                          msg: 'An error has occurred, please try again',
                                          toastLength: Toast.LENGTH_LONG);
                                      developer.log('$e');
                                  }
                                }
                                developer.log('$e');
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    editable = true;
                                  });
                                }
                              }
                            }
                          : () => {},
                      child: const Text('Save'),
                    ),
                  ]),
                ],
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: widget.theme,
      child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Profile'),
          ),
          body: Column(
            children: [
              const SizedBox.square(dimension: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _changePicture,
                    child: ClipOval(child: buildAvatar(widget.user, 128)),
                  ),
                ],
              ),
              const SizedBox.square(dimension: 16),
              Row(
                children: [
                  const SizedBox.square(dimension: 16),
                  const Icon(Icons.person),
                  const SizedBox.square(dimension: 16),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('First Name', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox.square(dimension: 4),
                        Text(widget.user.firstName!, style: const TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => editName('first'), icon: const Icon(Icons.edit)),
                  const SizedBox.square(dimension: 16),
                ],
              ),
              const SizedBox.square(dimension: 16),
              Row(
                children: [
                  const SizedBox.square(dimension: 16),
                  const Icon(Icons.person),
                  const SizedBox.square(dimension: 16),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Last Name', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox.square(dimension: 4),
                        Text(widget.user.lastName!, style: const TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => editName('last'), icon: const Icon(Icons.edit)),
                  const SizedBox.square(dimension: 16),
                ],
              ),
              const SizedBox.square(dimension: 16),
              Row(
                children: [
                  const SizedBox.square(dimension: 16),
                  const Icon(Icons.email),
                  const SizedBox.square(dimension: 16),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Email', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox.square(dimension: 4),
                        Text(FirebaseAuth.instance.currentUser!.email!, style: const TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => editEmail(), icon: const Icon(Icons.edit)),
                  const SizedBox.square(dimension: 16),
                ],
              ),
              const SizedBox.square(dimension: 16),
              Row(
                children: [
                  const SizedBox.square(dimension: 16),
                  const Icon(Icons.password),
                  const SizedBox.square(dimension: 16),
                  const Expanded(
                    child: Column(
                      children: [
                        Text('Password', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        SizedBox.square(dimension: 4),
                        Text('********', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => editPassword(), icon: const Icon(Icons.edit)),
                  const SizedBox.square(dimension: 16),
                ],
              ),
            ],
          )),
    );
  }
}
