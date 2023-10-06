import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';

import 'chat.dart';
import 'util.dart';

class UsersPage extends StatefulWidget {
  final ThemeData theme;

  const UsersPage({super.key, required this.theme});

  @override
  State<UsersPage> createState() => UsersPageState();
}

class UsersPageState extends State<UsersPage> {
  Map<String, types.Room> usersMap = {};
  final TextEditingController _searchController = TextEditingController();
  List<types.User> _users = [];

  @override
  void initState() {
    super.initState();
    getUserRooms();
    _searchUsers('');
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      _users = await getFCC().users().first;
      setState(() {
        _users.removeWhere((element) => element.id == getFCC().firebaseUser!.uid);
      });
      return;
    }
    try {
      final usersCollection = getFirebaseFirestore().collection(getFCC().config.usersCollectionName);
      _users = await usersCollection
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: query)
          // .where(FieldPath.documentId, isLessThan: '${query}z')
          .get()
          .then((snapshot) {
        return snapshot.docs.map((e) {
          final data = e.data();
          data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
          data['id'] = e.id;
          data['lastSeen'] = data['lastSeen']?.millisecondsSinceEpoch;
          data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;
          return types.User.fromJson(data);
        }).toList();
      });
      _users.removeWhere((element) => element.id == getFCC().firebaseUser!.uid);
      setState(() {});
    } catch (e) {
      developer.log('Error: $e');
    }
  }

  void _handlePressed(types.User otherUser, BuildContext context) async {
    final navigator = Navigator.of(context);
    if (usersMap.containsKey(otherUser.id)) {
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ChatPage(
            room: usersMap[otherUser.id]!,
            theme: widget.theme,
          ),
        ),
      );
    } else {
      final room = await FirebaseChatCore.instance.createRoom(otherUser);
      final fcc = getFCC();
      Map<String, dynamic> roomKey = {};
      Uint8List symmetricKey = await NativeCommunication.generateSymmetricKey();
      roomKey[otherUser.id] =
          base64Encode(await NativeCommunication.encryptKey(symmetricKey, await getPublicKey(otherUser.id)));
      final currentUserId = fcc.firebaseUser!.uid;
      roomKey[currentUserId] =
          base64Encode(await NativeCommunication.encryptKey(symmetricKey, await getPublicKey(currentUserId)));
      developer.log('Other user key length: ${roomKey[otherUser.id]!.length}');
      developer.log('Current user key length: ${roomKey[currentUserId]!.length}');
      fcc.getFirebaseFirestore().collection(fcc.config.roomsCollectionName).doc(room.id).update({'roomKey': roomKey});
      navigator.pop();
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => ChatPage(
            room: room,
            theme: widget.theme,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: widget.theme,
        child: Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchUsers(value);
              },
              decoration: InputDecoration(
                labelText: 'Search',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchUsers('');
                  },
                ),
              ),
            ),
          ),
          body: _users.isEmpty
              ? Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(
                    bottom: 200,
                  ),
                  child: const Text('No users'),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return GestureDetector(
                      onTap: () {
                        _handlePressed(user, context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            ClipOval(child: buildAvatar(user, 20)),
                            Container(
                              padding: const EdgeInsets.only(left: 16),
                            ),
                            Text(getUserName(user)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          // body: FutureBuilder<Stream<List<types.User>>>(
          //     future: nonChatUsers(),
          //     builder: (context, snapshot) {
          //       if (!snapshot.hasData ||
          //           snapshot.connectionState == ConnectionState.waiting ||
          //           snapshot.connectionState == ConnectionState.active) {
          //         return Container(
          //           alignment: Alignment.center,
          //           margin: const EdgeInsets.only(
          //             bottom: 200,
          //           ),
          //           child: const CircularProgressIndicator(),
          //         );
          //       }
          //       if (snapshot.connectionState == ConnectionState.done) {
          //         return StreamBuilder<List<types.User>>(
          //           stream: snapshot.data!,
          //           initialData: const [],
          //           builder: (context, snapshot) {
          //             if (!snapshot.hasData || snapshot.data!.isEmpty) {
          //               return Container(
          //                 alignment: Alignment.center,
          //                 margin: const EdgeInsets.only(
          //                   bottom: 200,
          //                 ),
          //                 child: const Text('No users'),
          //               );
          //             }
          //             return ListView.builder(
          //               itemCount: snapshot.data!.length,
          //               itemBuilder: (context, index) {
          //                 final user = snapshot.data![index];
          //                 return GestureDetector(
          //                   onTap: () {
          //                     _handlePressed(user, context);
          //                   },
          //                   child: Container(
          //                     padding: const EdgeInsets.symmetric(
          //                       horizontal: 16,
          //                       vertical: 8,
          //                     ),
          //                     child: Row(
          //                       children: [
          //                         ClipOval(child: buildAvatar(user, 20)),
          //                         Container(
          //                           padding: const EdgeInsets.only(left: 16),
          //                         ),
          //                         Text(getUserName(user)),
          //                       ],
          //                     ),
          //                   ),
          //                 );
          //               },
          //             );
          //           },
          //         );
          //       }
          //       return Container(
          //         alignment: Alignment.center,
          //         margin: const EdgeInsets.only(
          //           bottom: 200,
          //         ),
          //         child: const CircularProgressIndicator(
          //           value: 0.5,
          //           color: Colors.red,
          //         ),
          //       );
          //     }),
        ),
      );

  //Returns a stream of users who are not in a room with the current user - I'm not using it but I've worked so hard
  //to make it work so I'm not going to delete this
  Future<Stream<List<types.User>>> nonChatUsers() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final config = FirebaseChatCore.instance.config;
      if (firebaseUser == null) return const Stream.empty();

      // Create a reference to the users collection
      final usersCollection = getFirebaseFirestore().collection(config.usersCollectionName);

      // Create a subquery to filter users who are in rooms with the current user
      final usersInRoomsQuery = getFirebaseFirestore()
          .collection(config.roomsCollectionName)
          .where('userIds', arrayContains: firebaseUser.uid);
      List<String> usersInRooms = await getIdsFromQuery(usersInRoomsQuery);
      List<String> users = [];
      await usersCollection.get().then((value) {
        for (final user in value.docs) {
          users.add(user.id);
        }
      });
      developer.log('First users list: $users');
      for (final user in usersInRooms) {
        users.removeWhere((element) => element == user);
      }
      developer.log('Final users list: $users');
      return usersCollection.where(FieldPath.documentId, whereIn: users).get().then((snapshot) {
        return snapshot.docs.map((e) {
          final data = e.data();
          data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
          data['id'] = e.id;
          data['lastSeen'] = data['lastSeen']?.millisecondsSinceEpoch;
          data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;
          return types.User.fromJson(data);
        }).toList();
      }).asStream();
    } catch (e) {
      developer.log('Error: $e');
      return const Stream.empty();
    }
  }

  //Edits the map so each key is a user id and each value is a room with the current user and the user with the key
  Future<void> getUserRooms() async {
    try {
      Stream<List<types.Room>> roomsStream = getFCC().rooms();
      if (await roomsStream.isEmpty) return;
      List<types.Room> rooms = await roomsStream.first;
      for (final room in rooms) {
        final otherUser = room.users.firstWhere((element) => element.id != getFCC().firebaseUser!.uid);
        usersMap[otherUser.id] = room;
      }
    } catch (e) {
      developer.log('Error: $e');
    }
  }

  //Gets the ids of users in a rooms query
  Future<List<String>> getIdsFromQuery(Query query) async {
    final querySnapshot = await query.get();
    List<String> ids = [];
    for (final roomId in querySnapshot.docs.map((e) => e.id)) {
      await getUserIdsInRoom(roomId).then((value) => ids.addAll(value));
    }
    return ids;
  }

  FirebaseFirestore getFirebaseFirestore() => FirebaseFirestore.instance;
}