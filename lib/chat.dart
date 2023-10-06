import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'util.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.room,
    required this.theme,
  });

  final types.Room room;
  final ThemeData theme;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isAttachmentUploading = false;
  final double imageRadius = 20;
  Uint8List? roomKey;

  @override
  void initState() {
    super.initState();
    setRoomKey();
  }

  Future<void> setRoomKey() async {
    final fcc = getFCC();
    var keyMap = await fcc
        .getFirebaseFirestore()
        .collection(fcc.config.roomsCollectionName)
        .doc(widget.room.id)
        .get()
        .then((value) => value.data()!['roomKey']);
    var key = base64Decode(keyMap != null ? keyMap[fcc.firebaseUser!.uid] : '');
    developer.log('Room key: $key');
    Uint8List keyBytes = await NativeCommunication.decryptKey(key);
    developer.log('Decrypted room key: $keyBytes');
    setState(() {
      roomKey = keyBytes;
    });
  }

  void _handleAtachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('File'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      _setAttachmentUploading(true);
      final name = result.files.single.name;
      final filePath = result.files.single.path!;
      final file = File(filePath);
      String finishedName = '${FirebaseChatCore.instance.firebaseUser!.uid}_$name';
      try {
        final reference = FirebaseStorage.instance.ref(finishedName);
        await reference.putFile(file);
        final uri = await reference.getDownloadURL();

        final message = types.PartialFile(
          mimeType: lookupMimeType(filePath),
          name: finishedName,
          size: result.files.single.size,
          uri: uri,
        );
        sendNotification(widget.room.id, '📎 File');
        FirebaseChatCore.instance.sendMessage(message, widget.room.id);
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      _setAttachmentUploading(true);
      final file = File(result.path);
      final size = file.lengthSync();
      Uint8List bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);
      final name = result.name;
      String finishedName = '${FirebaseChatCore.instance.firebaseUser!.uid}_$name';
      try {
        final reference = FirebaseStorage.instance.ref(finishedName);
        await reference.putData(bytes);
        final uri = await reference.getDownloadURL();

        final message = types.PartialImage(
          height: image.height.toDouble(),
          name: finishedName,
          size: size,
          uri: uri,
          width: image.width.toDouble(),
        );
        sendNotification(widget.room.id, '📷 Image');
        FirebaseChatCore.instance.sendMessage(
          message,
          widget.room.id,
        );
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final updatedMessage = message.copyWith(isLoading: true);
          FirebaseChatCore.instance.updateMessage(
            updatedMessage,
            widget.room.id,
          );

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final updatedMessage = message.copyWith(isLoading: false);
          FirebaseChatCore.instance.updateMessage(
            updatedMessage,
            widget.room.id,
          );
        }
      }

      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final updatedMessage = message.copyWith(previewData: previewData);

    FirebaseChatCore.instance.updateMessage(updatedMessage, widget.room.id);
  }

  //   void _handleLongPress(BuildContext buildContext, types.Message message) {
//     final index = _messages.indexWhere((element) => element.id == message.id);
//     if (index != -1) {
//       setState(() {
//         _messages[_messages.indexOf(message)] = types.TextMessage(
//             author: _user,
//             createdAt: DateTime.now().millisecondsSinceEpoch,
//             id: randomString(),
//             text: "This message has been deleted");
//       });
//     }
//     developer.log("Long pressed message: ${message.type} at index {$index}");
//   }
// }

  void _handleSendPressed(types.PartialText message) async {
    sendNotification(widget.room.id, message.text);
    String text = await NativeCommunication.encryptMessage(roomKey!, message.text);
    developer.log('Message after encryption is $text, before encryption ${message.text}');
    types.PartialText newMessage = types.PartialText(
        metadata: message.metadata,
        previewData: message.previewData,
        repliedMessage: message.repliedMessage,
        text: text);
    FirebaseChatCore.instance.sendMessage(
      newMessage,
      widget.room.id,
    );
  }

  void _setAttachmentUploading(bool uploading) {
    setState(() {
      _isAttachmentUploading = uploading;
    });
  }

  Stream<List<types.Message>> messages(
    types.Room room, {
    List<Object?>? endAt,
    List<Object?>? endBefore,
    int? limit,
    List<Object?>? startAfter,
    List<Object?>? startAt,
  }) {
    final fcc = getFCC();
    var query = fcc
        .getFirebaseFirestore()
        .collection('${fcc.config.roomsCollectionName}/${room.id}/messages')
        .orderBy('createdAt', descending: true);

    if (endAt != null) {
      query = query.endAt(endAt);
    }

    if (endBefore != null) {
      query = query.endBefore(endBefore);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    if (startAfter != null) {
      query = query.startAfter(startAfter);
    }

    if (startAt != null) {
      query = query.startAt(startAt);
    }
    Stream<List<types.Message>> stream = query.snapshots().map(
          (snapshot) => snapshot.docs.fold<List<types.Message>>(
            [],
            (previousValue, doc) {
              final data = doc.data();
              final author = room.users.firstWhere(
                (u) => u.id == data['authorId'],
                orElse: () => types.User(id: data['authorId'] as String),
              );

              data['author'] = author.toJson();
              data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
              data['id'] = doc.id;
              data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;
              return [...previousValue, types.Message.fromJson(data)];
            },
          ),
        );
    return stream.asyncMap((event) async {
      for (var message in event) {
        if (message is types.TextMessage) {
          final newText = await NativeCommunication.decryptMessage(roomKey!, message.text);
          event[event.indexOf(message)] = message.copyWith(text: newText);
        }
      }
      return event;
    });
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Theme(
  //     data: widget.theme,
  //     child: Scaffold(
  //         appBar: AppBar(
  //           leading: IconButton(
  //             icon: const Icon(Icons.arrow_back),
  //             onPressed: () => Navigator.of(context).pop(),
  //           ),
  //           title: Row(
  //             children: [
  //               GestureDetector(
  //                 onTap: () => setState(() {
  //                   Navigator.of(context).push(MaterialPageRoute(
  //                     builder: (builder) =>
  //                         ImageDetailPage(image: getChatImage(widget.room, MediaQuery.of(context).size.width / 2.5)),
  //                   ));
  //                 }),
  //                 child: Hero(
  //                   tag: 'avatar',
  //                   child: CircleAvatar(
  //                     backgroundColor: Colors.transparent,
  //                     radius: imageRadius,
  //                     child: ClipOval(
  //                       child: widget.room.imageUrl != null
  //                           ? getChatImage(widget.room, imageRadius)
  //                           : ClipOval(
  //                               child: Image.asset('assets/images/anon.jpg',
  //                                   width: imageRadius * 2, height: imageRadius * 2)),
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox.square(
  //                 dimension: 16,
  //               ),
  //               widget.room.name != null ? Text(widget.room.name!) : const Text('No Name Found'),
  //             ],
  //           ),
  //           systemOverlayStyle: SystemUiOverlayStyle.light,
  //         ),
  //         body: StreamBuilder<types.Room>(
  //           initialData: widget.room,
  //           stream: FirebaseChatCore.instance.room(widget.room.id),
  //           builder: (context, snapshot) => FutureBuilder(
  //               future: messages(snapshot.data!),
  //               builder: (context, snapshot) {
  //                 if (snapshot.connectionState != ConnectionState.done) {
  //                   return StreamBuilder<List<types.Message>>(
  //                       initialData: const [],
  //                       stream: const Stream.empty(),
  //                       builder: (context, snapshot) {
  //                         return Chat(
  //                           theme: widget.theme == ThemeData.dark() ? const DarkChatTheme() : const DefaultChatTheme(),
  //                           isAttachmentUploading: _isAttachmentUploading,
  //                           messages: snapshot.data ?? [],
  //                           onAttachmentPressed: _handleAtachmentPressed,
  //                           onMessageTap: _handleMessageTap,
  //                           onPreviewDataFetched: _handlePreviewDataFetched,
  //                           onSendPressed: _handleSendPressed,
  //                           user: types.User(
  //                             id: FirebaseChatCore.instance.firebaseUser?.uid ?? '',
  //                           ),
  //                         );
  //                       });
  //                 }
  //                 return StreamBuilder<List<types.Message>>(
  //                     initialData: const [],
  //                     stream: snapshot.data!,
  //                     builder: (context, snapshot) {
  //                       return Chat(
  //                         theme: widget.theme == ThemeData.dark() ? const DarkChatTheme() : const DefaultChatTheme(),
  //                         isAttachmentUploading: _isAttachmentUploading,
  //                         messages: snapshot.data ?? [],
  //                         onAttachmentPressed: _handleAtachmentPressed,
  //                         onMessageTap: _handleMessageTap,
  //                         onPreviewDataFetched: _handlePreviewDataFetched,
  //                         onSendPressed: _handleSendPressed,
  //                         user: types.User(
  //                           id: FirebaseChatCore.instance.firebaseUser?.uid ?? '',
  //                         ),
  //                       );
  //                     });
  //               }),
  //         )),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: widget.theme,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (builder) =>
                        ImageDetailPage(image: getChatImage(widget.room, MediaQuery.of(context).size.width / 2.5)),
                  ));
                }),
                child: Hero(
                  tag: 'avatar',
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: imageRadius,
                    child: ClipOval(
                      child: widget.room.imageUrl != null
                          ? getChatImage(widget.room, imageRadius)
                          : ClipOval(
                              child: Image.asset('assets/images/anon.jpg',
                                  width: imageRadius * 2, height: imageRadius * 2)),
                    ),
                  ),
                ),
              ),
              const SizedBox.square(
                dimension: 16,
              ),
              widget.room.name != null ? Text(widget.room.name!) : const Text('No Name Found'),
            ],
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: StreamBuilder<types.Room>(
          initialData: widget.room,
          stream: FirebaseChatCore.instance.room(widget.room.id),
          builder: (context, snapshot) => StreamBuilder<List<types.Message>>(
              initialData: const [],
              stream: messages(snapshot.data!),
              builder: (context, snapshot) {
                return Chat(
                  theme: widget.theme == ThemeData.dark() ? const DarkChatTheme() : const DefaultChatTheme(),
                  isAttachmentUploading: _isAttachmentUploading,
                  messages: snapshot.data ?? [],
                  onAttachmentPressed: _handleAtachmentPressed,
                  onMessageTap: _handleMessageTap,
                  onPreviewDataFetched: _handlePreviewDataFetched,
                  onSendPressed: _handleSendPressed,
                  user: types.User(
                    id: FirebaseChatCore.instance.firebaseUser?.uid ?? '',
                  ),
                );
              }),
        ),
      ),
    );
  }
}

class ImageDetailPage extends StatelessWidget {
  const ImageDetailPage({
    super.key,
    required this.image,
  });

  final Widget image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(); // Close the ImageDetailPage
      },
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Hero(
          tag: 'avatar', // Same unique tag as in ChatScreen
          // child: BackdropFilter(
          // filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(child: image),
          // ),
        ),
      ),
    );
  }
}
