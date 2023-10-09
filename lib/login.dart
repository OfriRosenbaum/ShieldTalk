import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'util.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  final ThemeData theme;

  const LoginPage({super.key, required this.theme});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  FocusNode? _focusNode;
  bool _loggingIn = false;
  bool _passwordVisible = false;
  TextEditingController? _passwordController;
  TextEditingController? _usernameController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _passwordController = TextEditingController(text: '');
    _usernameController = TextEditingController(text: '');
  }

  void _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loggingIn = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _usernameController!.text,
        password: _passwordController!.text,
      );
      saveRegistrationToken();
      if (!mounted) return;
    } catch (e) {
      setState(() {
        _loggingIn = false;
      });
      String text;
      if (e is FirebaseException) {
        switch (e.code) {
          case 'user-not-found':
            text = 'No user found for that email.';
            break;
          case 'wrong-password':
            text = 'Wrong password.';
            break;
          case 'invalid-email':
            text = 'Invalid email.';
            break;
          case 'user-disabled':
            text = 'User disabled.';
            break;
          case 'too-many-requests':
            text = 'Too many requests.';
            break;
          case 'operation-not-allowed':
            text = 'Operation not allowed.';
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
            title: const Text('Login'),
          ),
          body: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
              child: Column(
                children: [
                  TextField(
                    autocorrect: false,
                    autofillHints: _loggingIn ? null : [AutofillHints.email],
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
                    readOnly: _loggingIn,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      autocorrect: false,
                      autofillHints: _loggingIn ? null : [AutofillHints.password],
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
                      onEditingComplete: _login,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _loggingIn ? null : _login,
                    child: const Text('Login'),
                  ),
                  const SizedBox.square(
                    dimension: 16,
                  ),
                  ElevatedButton(
                    onPressed: _loggingIn
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    RegisterPage(theme: widget.theme, email: _usernameController!.value.text),
                              ),
                            );
                          },
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
