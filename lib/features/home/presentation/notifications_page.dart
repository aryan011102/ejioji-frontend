import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../shared/format.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';

/// What happened while you were away: chat requests, matches, the latest
/// message in each conversation, anything a moderator took down, and new
/// tiles, from the last 30 days.
///
/// The server works every row out from what is true now, so a declined
/// request or an unmatched person is simply not here. Opening the page marks
/// everything on it seen; the dots stay for this visit, so you can see which
/// rows were new, and the bell's dot clears behind you.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  ActivityPage? _page;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load(markSeen: true));
  }

  Future<void> _load({bool markSeen = false}) async {
    final repository = ref.read(activityRepositoryProvider);
    try {
      final page = await repository.load();
      if (!mounted) return;
      setState(() {
        _page = page;
        _error = null;
      });
      if (markSeen && page.newCount > 0) {
        await repository.markSeen();
        // The bell reads the provider, not this snapshot.
        if (mounted) ref.invalidate(activityProvider);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _open(ActivityItem item) {
    switch (item.kind) {
      case ActivityKind.request:
        // Answered in the Requested section, where the whole card is.
        context.go(Routes.chats);
      case ActivityKind.match || ActivityKind.message:
        final id = item.matchId;
        if (id != null) context.push(Routes.conversationWith(id));
      case ActivityKind.takenDown:
        context.push(Routes.editInfo);
      case ActivityKind.tilesReady:
        context.push(Routes.editSources);
      case ActivityKind.unknown:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      navBar: AppNavBar(
        title: 'Notifications',
        backLabel: 'Home',
        onBack: () => context.pop(),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    final page = _page;
    final error = _error;
    if (page == null && error != null) {
      return ErrorView(error: error, onRetry: () => unawaited(_load()));
    }
    if (page == null) return const LoadingView();
    if (page.items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Nothing yet',
        body: 'Chat requests, matches and messages show up here.',
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.row,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: [
          SectionGroup(
            children: [
              for (final (i, item) in page.items.indexed)
                ActivityRow(
                  item: item,
                  last: i == page.items.length - 1,
                  onTap: () => _open(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What a row says: a bold line and the one under it.
///
/// Kept apart from the widget so the copy can be read, and tested, in one
/// place.
({String title, String body}) activityCopy(ActivityItem item) {
  final name = item.person?.displayName ?? 'Someone';
  return switch (item.kind) {
    ActivityKind.request => (
        title: '$name wants to chat',
        body: 'See their profile and decide.',
      ),
    ActivityKind.match => (
        title: 'You and $name matched',
        body: 'You can both write now.',
      ),
    ActivityKind.message => (
        title: '$name sent you a message',
        body: switch (item.messageKind) {
          MessageKind.photo => 'Sent a photo.',
          MessageKind.video => 'Sent a video.',
          _ => '“${item.preview ?? ''}”',
        },
      ),
    ActivityKind.takenDown => (
        title: 'A photo or video was taken down',
        body: _takedownReason(item.reason),
      ),
    ActivityKind.tilesReady => (
        title: item.count == 1
            ? '1 new tile to pick from'
            : '${item.count ?? 0} new tiles to pick from',
        body: 'Add any of them to your profile.',
      ),
    ActivityKind.unknown => (title: '', body: ''),
  };
}

/// The moderator's reason, as the person it happened to reads it. The list is
/// a draft on the server (media/models.py, TakedownReason).
String _takedownReason(String? reason) => switch (reason) {
      'someone_else' => 'It did not look like it was of you.',
      'sexual' => 'It broke the rules on sexual content.',
      'hateful' => 'It broke the rules on hateful content.',
      'child' => 'It showed a child, or someone who looks under 18.',
      'contact_details' => 'It had contact details in it.',
      _ => 'It broke the community rules.',
    };

class ActivityRow extends StatelessWidget {
  const ActivityRow({
    required this.item,
    required this.last,
    required this.onTap,
    super.key,
  });

  final ActivityItem item;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = activityCopy(item);
    final person = item.person;
    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (person != null)
                  Avatar(
                    seedColor: AppColors.fill,
                    size: 50,
                    imageUrl: person.photo?.stillUrl,
                  )
                else
                  _SystemGlyph(kind: item.kind),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong.copyWith(fontSize: 16.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        copy.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.footnote.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      relativeTime(item.at.toLocal()),
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    if (item.isNew)
                      Container(
                        key: const ValueKey('new-dot'),
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.pink,
                          shape: BoxShape.circle,
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

/// The circle on a row that is about you rather than about someone.
class _SystemGlyph extends StatelessWidget {
  const _SystemGlyph({required this.kind});

  final ActivityKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.fill2,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Icon(
        kind == ActivityKind.takenDown
            ? Icons.shield_outlined
            : Icons.auto_awesome_outlined,
        size: 22,
        color: AppColors.accent,
      ),
    );
  }
}
