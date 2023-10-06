import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:shield_talk/util.dart';

class RegisterPage extends StatefulWidget {
  final ThemeData theme;

  const RegisterPage({super.key, required this.theme});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  FocusNode? _focusNode;
  bool _registering = false;
  bool _passwordVisible = false;
  TextEditingController? _usernameController;
  TextEditingController? _passwordController;
  TextEditingController? _firstNameController;
  TextEditingController? _lastNameController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _passwordController = TextEditingController();
    _usernameController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
  }

  void _register() async {
    FocusScope.of(context).unfocus();

    String firstName = _firstNameController!.text.trim();
    String lastName = _lastNameController!.text.trim();
    if (firstName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid first name'),
        ),
      );
      return;
    }
    if (lastName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid last name'),
        ),
      );
      return;
    }
    setState(() {
      _registering = true;
    });
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _usernameController!.text,
        password: _passwordController!.text,
      );
      await credential.user?.sendEmailVerification();
      final userId = credential.user!.uid;
      await FirebaseChatCore.instance.createUserInFirestore(
        types.User(
          firstName: firstName,
          id: userId,
          imageUrl: null,
          lastName: lastName,
        ),
      );
      await savePublicKey(userId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _registering = false;
      });
      String text;
      if (e is FirebaseException) {
        switch (e.code) {
          case 'email-already-in-use':
            text = 'Email already in use.';
            break;
          case 'invalid-email':
            text = 'Invalid email.';
            break;
          case 'operation-not-allowed':
            text = 'Operation not allowed.';
            break;
          case 'weak-password':
            text = 'Weak password.';
            break;
          case 'unknown':
            text = 'Unknown error.';
            break;
          default:
            text = e.toString();
            break;
        }
      } else {
        text = e.toString();
      }
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
          content: Text(
            text,
          ),
          title: const Text('Error'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    _passwordController?.dispose();
    _usernameController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: widget.theme,
        child: Scaffold(
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.light,
            title: const Text('Register'),
          ),
          body: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
              child: Column(
                children: [
                  TextField(
                    autocorrect: false,
                    autofillHints: _registering ? null : [AutofillHints.email],
                    autofocus: true,
                    controller: _usernameController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                      labelText: 'Email',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: () => _usernameController?.clear(),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onEditingComplete: () {
                      _focusNode?.requestFocus();
                    },
                    readOnly: _registering,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      autocorrect: false,
                      autofillHints: _registering ? null : [AutofillHints.password],
                      controller: _passwordController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        labelText: 'Password',
                        suffixIcon: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, // added line
                          mainAxisSize: MainAxisSize.min, // added line
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.cancel),
                              onPressed: () => _passwordController?.clear(),
                            ),
                            IconButton(
                              icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      focusNode: _focusNode,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: !_passwordVisible,
                      onEditingComplete: _register,
                      readOnly: _registering,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  TextField(
                    maxLength: 14,
                    autofillHints: _registering ? null : [AutofillHints.givenName],
                    autofocus: true,
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                      labelText: 'First Name',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: () => _firstNameController?.clear(),
                      ),
                    ),
                    keyboardType: TextInputType.name,
                    onEditingComplete: () {
                      _focusNode?.requestFocus();
                    },
                    readOnly: _registering,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    maxLength: 14,
                    autofillHints: _registering ? null : [AutofillHints.familyName],
                    autofocus: true,
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                      labelText: 'Last Name',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: () => _lastNameController?.clear(),
                      ),
                    ),
                    keyboardType: TextInputType.name,
                    onEditingComplete: () {
                      _focusNode?.requestFocus();
                    },
                    readOnly: _registering,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                  ),
                  ElevatedButton(
                    onPressed: _registering ? null : _register,
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
