import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:shield_talk/login.dart';

import 'chat.dart';
import 'users.dart';
import 'util.dart';
import 'settings.dart';
import 'verify_email.dart';

// ignore: must_be_immutable
class RoomsPage extends StatefulWidget {
  ThemeData theme;
  RoomsPage({super.key, required this.theme});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  bool _error = false;
  bool _initialized = false;
  User? _user;
  StreamSubscription<User?>? _authStateSubscription;
  late ThemeData _theme;

  @override
  void initState() {
    initializeFlutterFire();
    _theme = widget.theme;
    super.initState();
  }

  void updateTheme(bool isDark) {
    if (!mounted) return;
    setState(() {
      _theme = isDark ? ThemeData.dark() : ThemeData.light();
    });
  }

  void initializeFlutterFire() async {
    if (!mounted) return;
    try {
      _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        setState(() {
          _user = user;
        });
      });
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container();
    }

    if (!_initialized) {
      return Container();
    }

    return Theme(
        data: _theme,
        child: _user == null
            ? LoginPage(theme: _theme)
            : _user!.emailVerified
                ? Scaffold(
                    appBar: AppBar(
                      actions: [
                        PopupMenuButton(itemBuilder: (context) {
                          return [
                            const PopupMenuItem<int>(
                              value: 0,
                              child: Text("Add Chat"),
                            ),
                            const PopupMenuItem<int>(
                              value: 1,
                              child: Text("Settings"),
                            ),
                            const PopupMenuItem<int>(
                              value: 2,
                              child: Text("Logout"),
                            ),
                          ];
                        }, onSelected: (value) {
                          if (value == 0) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => UsersPage(theme: _theme),
                              ),
                            );
                          } else if (value == 1) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SettingsPage(
                                  updateThemeCallback: updateTheme,
                                ),
                              ),
                            );
                          } else if (value == 2) {
                            logout();
                          }
                        }),
                      ],
                      leading: IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: _user == null ? null : logout,
                      ),
                      systemOverlayStyle: SystemUiOverlayStyle.light,
                      title: const Text('Rooms'),
                    ),
                    body: StreamBuilder<List<types.Room>>(
                      stream: FirebaseChatCore.instance.rooms(),
                      initialData: const [],
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Container(
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(
                              bottom: 200,
                            ),
                            child: const Text('No rooms'),
                          );
                        }
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final room = snapshot.data![index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(room: room, theme: _theme),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    ClipOval(child: getChatImage(room, 20)),
                                    Container(
                                      padding: const EdgeInsets.only(left: 16),
                                    ),
                                    Text(room.name ?? ''),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                : VerifyEmailPage(
                    theme: _theme,
                  ));
  }
}
