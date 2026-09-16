import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';
import 'media.dart';
import 'person.dart';

/// One message.
///
/// [seq] is assigned by the server under the thread's lock, so the numbers are
/// in commit order. That is what makes "everything after 41" safe: it can
/// never miss a message that committed late.
@immutable
class Message {
  const Message({
    required this.id,
    required this.matchId,
    required this.seq,
    required this.senderId,
    required this.clientId,
    required this.kind,
    required this.sentAt,
    this.text,
    this.media,
  });

  final String id;
  final String matchId;
  final int seq;
  final String senderId;

  /// The id this device made before sending. A retry after a lost response is
  /// one message, not two, because the server keys on this.
  final String clientId;

  final MessageKind kind;
  final String? text;
  final MediaAsset? media;
  final DateTime sentAt;

  bool mine(String myUserId) => senderId == myUserId;

  static Message fromJson(Json j) {
    final media = j.objectOrNull('media');
    return Message(
      id: j.str('id'),
      matchId: j.str('match_id'),
      seq: j.intOr('seq', 0),
      senderId: j.str('sender_id'),
      clientId: j.str('client_id'),
      kind: MessageKind.parse(j.strOrNull('kind')),
      text: j.strOrNull('text'),
      media: media == null ? null : MediaAsset.fromJson(media),
      sentAt: j.time('sent_at'),
    );
  }

  static List<Message> listFrom(List<Json> items) =>
      items.map(Message.fromJson).toList(growable: false);
}

/// A page of a conversation, oldest-first, with both read marks.
@immutable
class MessagePage {
  const MessagePage({
    required this.messages,
    required this.hasMore,
    required this.myReadSeq,
    required this.theirReadSeq,
  });

  final List<Message> messages;
  final bool hasMore;
  final int myReadSeq;
  final int theirReadSeq;

  static MessagePage fromJson(Json j) => MessagePage(
        messages: Message.listFrom(j.objects('messages')),
        hasMore: j.flag('has_more'),
        myReadSeq: j.intOr('my_read_seq', 0),
        theirReadSeq: j.intOr('their_read_seq', 0),
      );
}

/// The last line of a conversation, as the list shows it.
@immutable
class LastMessage {
  const LastMessage({
    required this.seq,
    required this.senderId,
    required this.kind,
    required this.sentAt,
    this.preview,
  });

  final int seq;
  final String senderId;
  final MessageKind kind;
  final String? preview;
  final DateTime sentAt;

  static LastMessage fromJson(Json j) => LastMessage(
        seq: j.intOr('seq', 0),
        senderId: j.str('sender_id'),
        kind: MessageKind.parse(j.strOrNull('kind')),
        preview: j.strOrNull('preview'),
        sentAt: j.time('sent_at'),
      );
}

/// A row in the chats list. The match id is the conversation id; chat holds no
/// id of its own.
@immutable
class Conversation {
  const Conversation({
    required this.matchId,
    required this.matchedAt,
    required this.person,
    required this.unread,
    required this.theirReadSeq,
    this.lastMessage,
  });

  final String matchId;
  final DateTime matchedAt;
  final Person person;
  final LastMessage? lastMessage;
  final int unread;
  final int theirReadSeq;

  /// Nobody has written yet. The list leads with this rather than an empty row.
  bool get isNew => lastMessage == null;

  DateTime get sortAt => lastMessage?.sentAt ?? matchedAt;

  static Conversation fromJson(Json j) {
    final last = j.objectOrNull('last_message');
    return Conversation(
      matchId: j.str('match_id'),
      matchedAt: j.time('matched_at'),
      person: Person.fromJson(j.object('person')),
      lastMessage: last == null ? null : LastMessage.fromJson(last),
      unread: j.intOr('unread', 0),
      theirReadSeq: j.intOr('their_read_seq', 0),
    );
  }

  static List<Conversation> listFrom(List<Json> items) =>
      items.map(Conversation.fromJson).toList(growable: false);
}
