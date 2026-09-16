import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/person.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/sheets.dart';
import '../../../shared/widgets/states.dart';

enum _Tab { chats, requests, sent }

/// The second tab.
///
/// Nobody can write to anybody until a request has been accepted, so these
/// three lists are one flow rather than three inboxes: a request arrives,
/// it is answered, and answering it is what opens the conversation.
///
/// There is no starred list. Starring was in the original design and has
/// nothing behind it; a private shortlist that only survives until the app is
/// reinstalled is worse than none.
class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  _Tab _tab = _Tab.chats;

  /// Answering a request opens a conversation, so both lists and the feed all
  /// move at once.
  void _refreshEverything() {
    ref
      ..invalidate(conversationsProvider)
      ..invalidate(incomingRequestsProvider)
      ..invalidate(outgoingRequestsProvider);
  }

  Future<void> _accept(PendingRequest request) async {
    try {
      final match =
          await ref.read(matchingRepositoryProvider).accept(request.id);
      if (!mounted) return;
      _refreshEverything();
      context.push(Routes.conversationWith(match.id));
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  Future<void> _decline(PendingRequest request) async {
    // Declining is final, and the other person is never told: their request
    // just leaves their sent list. Worth confirming once, because there is no
    // way back from it.
    final choice = await showAppActionSheet(
      context,
      title: 'Decline ${request.person.firstName}?',
      message: 'They are not told. You will not be shown to each other again.',
      actions: const [SheetAction('Decline', destructive: true)],
    );
    if (choice != 0 || !mounted) return;

    try {
      await ref.read(matchingRepositoryProvider).decline(request.id);
      if (!mounted) return;
      _refreshEverything();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingRequestsProvider);
    final waiting = incoming.valueOrNull?.length ?? 0;

    return AppScaffold(
      child: Column(
        children: [
          const LargeTitle('Chats'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              10,
            ),
            child: SegmentedControl<_Tab>(
              value: _tab,
              options: [
                (_Tab.chats, 'Chats'),
                (_Tab.requests, waiting > 0 ? 'Requests ($waiting)' : 'Requests'),
                (_Tab.sent, 'Sent'),
              ],
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _Tab.chats => _ConversationList(onChanged: _refreshEverything),
              _Tab.requests => _IncomingList(
                  onAccept: _accept,
                  onDecline: _decline,
                ),
              _Tab.sent => const _SentList(),
            },
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return conversations.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(conversationsProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.forum_outlined,
            title: 'No conversations yet',
            body: 'When you and someone else both say yes, the conversation '
                'opens here. Nobody can write before that.',
          );
        }

        // Newest activity first. A conversation nobody has written in yet
        // sorts by when it opened, so a fresh match does not fall to the
        // bottom of the list it just joined.
        final sorted = [...rows]
          ..sort((a, b) => b.sortAt.compareTo(a.sortAt));

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.row,
          onRefresh: () async => onChanged(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 150),
            children: [
              SectionGroup(
                children: [
                  for (final c in sorted)
                    _ConversationRow(
                      conversation: c,
                      last: c.matchId == sorted.last.matchId,
                      onTap: () =>
                          context.push(Routes.conversationWith(c.matchId)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IncomingList extends ConsumerWidget {
  const _IncomingList({required this.onAccept, required this.onDecline});

  final Future<void> Function(PendingRequest) onAccept;
  final Future<void> Function(PendingRequest) onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider);

    return incoming.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(incomingRequestsProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.mark_email_unread_outlined,
            title: 'Nobody is waiting',
            body: 'When someone asks to chat, they wait here until you answer. '
                'There is no time limit and nothing expires.',
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 150),
          children: [
            for (final r in rows)
              _RequestCard(
                request: r,
                onAccept: () => onAccept(r),
                onDecline: () => onDecline(r),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.titleGutter,
              ),
              child: Text(
                'Accepting opens the conversation. Declining is final and they '
                'are not told.',
                style: AppText.caption,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SentList extends ConsumerWidget {
  const _SentList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outgoing = ref.watch(outgoingRequestsProvider);

    return outgoing.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(outgoingRequestsProvider),
      ),
      data: (out) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 150),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.titleGutter,
                0,
                Insets.titleGutter,
                14,
              ),
              child: Text(
                out.leftToday > 0
                    ? '${out.leftToday} more ${out.leftToday == 1 ? 'request' : 'requests'} today. '
                        'They come back ${timeUntil(out.resetsAt)}.'
                    : 'No requests left today. They come back '
                        '${timeUntil(out.resetsAt)}.',
                style: AppText.callout,
              ),
            ),
            if (out.requests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.send_outlined,
                  title: 'Nothing sent yet',
                  body: 'Requests you send sit here until they are answered.',
                ),
              )
            else
              SectionGroup(
                footer: 'A request that is answered leaves this list. You are '
                    'not told which way it went.',
                children: [
                  for (final r in out.requests)
                    AppRow(
                      label: r.person.firstName,
                      subtitle: 'Asked ${relativeTime(r.requestedAt)} ago',
                      last: r.id == out.requests.last.id,
                      leading: Avatar(
                        seedColor: AppColors.fill,
                        size: 29,
                        imageUrl: r.person.leadPhoto?.stillUrl,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// An incoming request, shown as a card rather than a row.
///
/// The point of this section is that someone is seen properly before being
/// answered, and a one-line row with a name on it is not enough to decide
/// something final.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final PendingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final person = request.person;
    final photo = person.leadPhoto;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.row,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photo != null)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  photo.stillUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppColors.photoEmpty),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${person.firstName}, ${person.age}',
                    style: AppText.title3.copyWith(fontSize: 19),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.city.label} · asked '
                    '${relativeTime(request.requestedAt)} ago',
                    style: AppText.footnote,
                  ),
                  if (person.tiles.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      person.tiles.first.isAnswer
                          ? person.tiles.first.headline
                          : '${person.tiles.first.headline} · '
                              '${person.tiles.first.body}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.callout,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Decline',
                          onPressed: onDecline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Chat',
                          onPressed: onAccept,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.last,
    required this.onTap,
  });

  final Conversation conversation;
  final bool last;
  final VoidCallback onTap;

  /// What the row says under the name.
  ///
  /// A photo or a video never shows a preview of itself here, and a match
  /// nobody has written in says so rather than showing an empty line.
  String get _preview {
    final message = conversation.lastMessage;
    if (message == null) return 'You can both write now. Say something.';
    return switch (message.kind) {
      MessageKind.text => message.preview ?? '',
      MessageKind.photo => 'Photo',
      MessageKind.video => 'Video',
    };
  }

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unread;

    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Avatar(
                  seedColor: AppColors.fill,
                  imageUrl: conversation.person.photo?.stillUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.person.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong.copyWith(fontSize: 16.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.footnote.copyWith(
                          fontSize: 14,
                          color: unread > 0
                              ? AppColors.label
                              : AppColors.label2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      relativeTime(conversation.sortAt),
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 20,
                      child: unread == 0
                          ? null
                          : Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              height: 20,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.fill,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unread',
                                style: AppText.micro.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onAccent,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 78),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.separator,
            ),
          ),
      ],
    );
  }
}
