import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const colors = [
  Color(0xffff6767),
  Color(0xff66e0da),
  Color(0xfff5a2d9),
  Color(0xfff0c722),
  Color(0xff6a85e5),
  Color(0xfffd9a6f),
  Color(0xff92db6e),
  Color(0xff73b8e5),
  Color(0xfffd7590),
  Color(0xffc78ae5),
];

const _storage = FlutterSecureStorage();
const _key = 'shield_talk_private_key';

IOSOptions _getIOSOptions() => const IOSOptions(
      accountName: 'flutter_secure_storage_service',
    );

AndroidOptions _getAndroidOptions() => const AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    );

Future<Uint8List> _getPrivateKey() async {
  log('${await _storage.containsKey(key: "$_key${FirebaseAuth.instance.currentUser!.uid}")}');
  return base64Decode(await _storage.read(key: "$_key${FirebaseAuth.instance.currentUser!.uid}") ?? '');
}

Future<void> _savePrivateKey(String key) async {
  await _storage.write(
    key: "$_key${FirebaseAuth.instance.currentUser!.uid}",
    value: key,
    iOptions: _getIOSOptions(),
    aOptions: _getAndroidOptions(),
  );
}

Color getUserAvatarNameColor(types.User user) {
  final index = user.id.hashCode % colors.length;
  return colors[index];
}

Future<ThemeData> getThemePreference() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('isDarkThemeEnabled') ?? false) {
    return ThemeData.dark();
  }
  return ThemeData.light();
}

Widget getChatImage(types.Room room, double imageRadius) {
  try {
    return CachedNetworkImage(
      imageUrl: room.imageUrl!,
      width: imageRadius * 2,
      height: imageRadius * 2,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) =>
          Image.asset('assets/images/anon.jpg', width: imageRadius * 2, height: imageRadius * 2),
    );
  } catch (e) {
    return Image.asset('assets/images/anon.jpg', width: imageRadius * 2, height: imageRadius * 2);
  }
}

Widget buildAvatar(types.User user, double imageRadius) {
  try {
    return CachedNetworkImage(
      imageUrl: user.imageUrl!,
      width: imageRadius * 2,
      height: imageRadius * 2,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) =>
          Image.asset('assets/images/anon.jpg', width: imageRadius * 2, height: imageRadius * 2),
    );
  } catch (e) {
    return Image.asset('assets/images/anon.jpg', width: imageRadius * 2, height: imageRadius * 2);
  }
}

Future<void> saveRegistrationToken() async {
  final fcc = getFCC();
  try {
    if (fcc.firebaseUser != null) {
      await fcc
          .getFirebaseFirestore()
          .collection(fcc.config.usersCollectionName)
          .doc(fcc.firebaseUser!.uid)
          .update({'registrationToken': await FirebaseMessaging.instance.getToken()});
    }
  } catch (e) {
    log('$e');
  }
}

Future<void> savePublicKey(String userId) async {
  final fcc = getFCC();
  try {
    if (fcc.firebaseUser != null) {
      await getFCC()
          .getFirebaseFirestore()
          .collection(fcc.config.usersCollectionName)
          .doc(userId)
          .update({'publicKey': await NativeCommunication.generateKeys()});
    }
  } catch (e) {
    log('$e');
  }
}

Future<Uint8List> getPublicKey(String userId) async {
  final fcc = getFCC();
  try {
    if (fcc.firebaseUser != null) {
      final userDoc = await fcc.getFirebaseFirestore().collection(fcc.config.usersCollectionName).doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final Uint8List decodedPublicKey = base64Decode(data['publicKey']);
          // return base64Decode(data['publicKey']);
          return decodedPublicKey;
        }
      }
    }
  } catch (e) {
    log('$e');
  }
  return Uint8List(0);
}

Future<void> askForNotificationPermission() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
}

Future<types.User> getFirestoreUser(User? user) async {
  if (user == null) throw Exception('User not found');
  final fcc = getFCC();
  final snapshot = await fcc.getFirebaseFirestore().collection(fcc.config.usersCollectionName).doc(user.uid).get();
  final data = snapshot.data()!;
  data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
  data['id'] = user.uid;
  data['lastSeen'] = data['lastSeen']?.millisecondsSinceEpoch;
  data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;
  return types.User.fromJson(data);
}

Future<void> sendNotification(String roomId, String message) async {
  try {
    final String recipient =
        await getTokenForUser(await getOtherUserId(roomId, FirebaseAuth.instance.currentUser!.uid));
    final body = {
      'to': recipient,
      'notification': {
        'title':
            'You have a new message from ${getUserName(await getFirestoreUser(FirebaseAuth.instance.currentUser))}',
        'body': message,
      }
    };
    var response = await post(Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'key=${DefaultFirebaseOptions.firebaseMessagingServerKey}',
        },
        body: jsonEncode(body));
    log('Response status: ${response.statusCode}');
    log('Response status: ${response.body}');
  } catch (e) {
    log('$e');
  }
}

//Gets the user ids of users in a room
Future<List<String>> getUserIdsInRoom(String roomId) async {
  final roomDoc = await getFCC().getFirebaseFirestore().collection('rooms').doc(roomId).get();
  if (roomDoc.exists) {
    final data = roomDoc.data();
    if (data != null) {
      return List<String>.from(data['userIds']);
    }
  }
  return [];
}

Future<String> getTokenForUser(String userId) async {
  final userDoc = await getFCC().getFirebaseFirestore().collection('users').doc(userId).get();
  if (userDoc.exists) {
    final data = userDoc.data();
    if (data != null) {
      return data['registrationToken'];
    }
  }
  return '';
}

Future<String> getOtherUserId(String roomId, String currentUserId) {
  return getUserIdsInRoom(roomId).then((value) => value.firstWhere((element) => element != currentUserId));
}

String getUserName(types.User user) => '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();

FirebaseChatCore getFCC() {
  return FirebaseChatCore.instance;
}

class NativeCommunication {
  static const MethodChannel _channel = MethodChannel('com.shieldtalk/security_channel');

  static Future<String> generateKeys() async {
    var keys = await _channel.invokeMethod('generateKeys'); //check type
    try {
      if (keys[0] is String) {
        await _savePrivateKey(keys[0]);
      } else {
        log("generateKeys: Key generation failed. Private key is not String.");
      }
      if (keys[1] is String) {
        return keys[1];
      } else {
        log("generateKeys: Key generation failed. Public key is not String.");
      }
    } on PlatformException catch (e) {
      log('${e.message} from generateKeys()');
    }
    return '';
  }

  static Future<String> decryptMessage(Uint8List key, String message) async {
    try {
      Uint8List privateKey = await _getPrivateKey();
      log('decryptMessage: Private key: ${privateKey.toString()}');
      final String decryptedMessage = await _channel.invokeMethod('decryptMessage', {'key': key, 'message': message});
      log('decryptMessage: Message to decrypt: $message using key $key');
      log('decryptMessage: Message decrypted: $decryptedMessage');
      return decryptedMessage;
    } on PlatformException catch (e) {
      log('${e.message} from decryptMessage()');
      return '';
    }
  }

  static Future<Uint8List> generateSymmetricKey() async {
    try {
      final Uint8List key = await _channel.invokeMethod('generateSymmetricKey');
      log('generateSymmetricKey: Symmetric key generated: ${key.toString()}');
      return key;
    } on PlatformException catch (e) {
      log('${e.message} from generateSymmetricKey()');
      return Uint8List(0);
    }
  }

  static Future<Uint8List> encryptKey(Uint8List keyToEncrypt, Uint8List publicKey) async {
    try {
      log('encryptKey: Key encription public key: ${publicKey.toString()}');
      log('encryptKey: Key encription key to encrypt: ${keyToEncrypt.toString()}');
      final Uint8List encryptedKey =
          await _channel.invokeMethod('encryptKey', {'keyToEncrypt': keyToEncrypt, 'publicKey': publicKey});
      log('encryptKey: Key encrypted: ${encryptedKey.toString()}');
      return encryptedKey;
    } on PlatformException catch (e) {
      log('${e.message} from encryptKey()');
      return Uint8List(0);
    }
  }

  static Future<Uint8List> decryptKey(Uint8List key) async {
    try {
      Uint8List privateKey = await _getPrivateKey();
      log('decryptKey: Key to encrypt $key');
      log('decryptKey: Using private key $privateKey');
      return await _channel.invokeMethod('decryptKey', {'keyToDecrypt': key, 'privateKey': privateKey});
    } on PlatformException catch (e) {
      log('${e.message} from decryptKey()');
      return Uint8List(0);
    }
  }

  static Future<String> encryptMessage(Uint8List key, String message) async {
    try {
      final String encryptedMessage = await _channel.invokeMethod('encryptMessage', {'key': key, 'message': message});
      log('encryptMessage: Message to encrypt: $message using key $key');
      log('encryptMessage: Message encrypted: $encryptedMessage');
      return encryptedMessage;
    } on PlatformException catch (e) {
      log('${e.message} from encryptMessage()');
      return '';
    }
  }
}
