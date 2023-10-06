import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:shield_talk/rooms.dart';

class VerifyEmailPage extends StatefulWidget {
  final ThemeData theme;
  const VerifyEmailPage({super.key, required this.theme});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isButtonEnabled = true;
  int _remaining = 0;
  Timer? _buttonTimer;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
  }

  @override
  void dispose() {
    _buttonTimer?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }

  void checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
      setState(() {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RoomsPage(theme: widget.theme),
          ),
        );
      });
    }
  }

  void _verifyEmail() async {
    if (_isButtonEnabled) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        user.reload();
        if (user.emailVerified) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RoomsPage(theme: widget.theme),
            ),
          );
        } else {
          await user.sendEmailVerification();
          Fluttertoast.showToast(
            msg: "Verification email sent to ${user.email}",
            toastLength: Toast.LENGTH_LONG,
          );
          _isButtonEnabled = false;
          _remaining = 60;
          _buttonTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            setState(() {
              if (_remaining > 0) {
                _remaining--;
              } else {
                _isButtonEnabled = true;
                timer.cancel();
              }
            });
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: widget.theme,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Email not verified'),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _verifyEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isButtonEnabled ? Colors.blue : Colors.grey,
                ),
                child: const Text('Send verification email'),
              ),
              SizedBox(height: _remaining > 0 ? 16.0 : 0.0),
              Text(
                _remaining > 0 ? 'You can resend email in $_remaining seconds' : '',
              ),
              SizedBox(height: _remaining > 0 ? 16.0 : 0.0),
              ElevatedButton(
                onPressed: FirebaseAuth.instance.signOut,
                style: ElevatedButton.styleFrom(),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
