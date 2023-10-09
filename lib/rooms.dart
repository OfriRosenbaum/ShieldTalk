import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  Map<String, String> _lastMessages = {};
  StreamSubscription<User?>? _authStateSubscription;
  late ThemeData _theme;

  @override
  void initState() {
    super.initState();
    initializeFlutterFire();
    _theme = widget.theme;
    getLastMessages();
    updateChat();
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

  //Edits the map so each key is a room id and each value is the last message in the room
  Future<void> getLastMessages() async {
    final fcc = getFCC();
    while (_user == null) {
      await Future.delayed(const Duration(seconds: 1));
    }
    try {
      Map<String, String> lastMessages = {};
      final query = await fcc
          .getFirebaseFirestore()
          .collection(fcc.config.roomsCollectionName)
          .where('userIds', arrayContains: _user!.uid)
          .get();
      List<String> roomIds = query.docs.map((e) => e.id).toList();
      for (String roomId in roomIds) {
        log(roomId);
        lastMessages[roomId] = await getLastMessage(roomId);
      }
      setState(() {
        _lastMessages = lastMessages;
      });
    } catch (e) {
      log('getLastMessages(): Error: $e');
    }
  }

  Future<void> updateChat() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.notification == null) return;
      final roomId = message.data['roomId'];
      if (roomId == null) return;
      setState(() {
        _lastMessages[roomId] =
            message.notification!.body != null ? message.data['firstName'] + ': ' + message.notification!.body! : '';
      });
    });
  }

  void lastMessageCallback(String roomId, String lastMessage) {
    setState(() {
      _lastMessages[roomId] = lastMessage;
    });
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
                                builder: (context) => UsersPage(theme: _theme, roomsCallback: getLastMessages),
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
                      stream: FirebaseChatCore.instance.rooms(orderByUpdatedAt: true),
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
                                    builder: (context) =>
                                        ChatPage(room: room, theme: _theme, callback: lastMessageCallback),
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
                                    ClipOval(child: getChatImage(room, 32)),
                                    Container(
                                      padding: const EdgeInsets.only(left: 16),
                                    ),
                                    Expanded(
                                        child: _lastMessages[room.id] == null
                                            ? Text(room.name ?? '', style: const TextStyle(fontSize: 16))
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(room.name ?? '', style: const TextStyle(fontSize: 16)),
                                                  Container(
                                                    padding: const EdgeInsets.only(left: 8),
                                                  ),
                                                  Text(_lastMessages[room.id] ?? '',
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 16))
                                                ],
                                              )),
                                    Container(
                                      padding: const EdgeInsets.only(left: 8),
                                    ),
                                    Text(room.updatedAt == null ? '' : getChatTime(room.updatedAt!),
                                        style: const TextStyle(fontSize: 16, color: Colors.grey)),
                                    Container(
                                      padding: const EdgeInsets.only(left: 16),
                                    ),
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
