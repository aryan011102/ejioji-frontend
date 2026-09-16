import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/mock/demo_data.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/identity.dart';
import '../../../shared/widgets/layout.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/states.dart';

enum _Tab { chats, requests, liked }

/// Anyone can write to anyone — there is no mutual-match gate — so the tabs
/// sort by whether a message has been answered rather than by who was paired.
///
/// Receiving is always allowed; only answering waits on verification, which is
/// why the banner counts what is waiting instead of scolding.
class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  _Tab _tab = _Tab.chats;

  List<DemoThread> get _rows => switch (_tab) {
        _Tab.chats => Demo.threads,
        _Tab.requests => Demo.requests,
        _Tab.liked => Demo.threads.where((t) => t.starred).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final canChat = ref.watch(sessionProvider).canChat;
    final rows = _rows;

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
              options: const [
                (_Tab.chats, 'Chats'),
                (_Tab.requests, 'Requests'),
                (_Tab.liked, 'Liked'),
              ],
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          if (!canChat)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.gutter,
                0,
                Insets.gutter,
                12,
              ),
              child: _VerifyBanner(
                waiting: Demo.requests.length,
                onVerify: () => context.push(Routes.verify),
              ),
            ),
          Expanded(
            child: rows.isEmpty
                ? EmptyState(
                    icon: _tab == _Tab.liked
                        ? Icons.star_border
                        : Icons.forum_outlined,
                    title: _tab == _Tab.liked
                        ? 'Nothing starred yet'
                        : 'No messages yet',
                    body: _tab == _Tab.liked
                        ? 'Star a chat to keep it here. Only you ever see this '
                            'list.'
                        : 'Anyone can write to you, and you can write to '
                            'anyone. Replying is optional.',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 150),
                    children: [
                      Opacity(
                        opacity: canChat ? 1 : 0.5,
                        child: SectionGroup(
                          children: [
                            for (final t in rows)
                              _ThreadRow(
                                thread: t,
                                showStar: _tab != _Tab.requests,
                                last: t.id == rows.last.id,
                                onTap: canChat
                                    ? () => context.push(
                                          Routes.conversationWith(t.id),
                                        )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                      if (_tab == _Tab.requests)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.titleGutter,
                          ),
                          child: Text(
                            'Answering moves a request into Chats. Ignoring '
                            'one does nothing and tells them nothing.',
                            style: AppText.caption,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.waiting, required this.onVerify});

  final int waiting;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.row,
        borderRadius: BorderRadius.circular(Radii.row),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lock, size: 15, color: AppColors.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$waiting people are waiting',
                  style: AppText.bodyStrong.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verify to answer them. An ID or a selfie — either one takes '
                  'a couple of minutes.',
                  style: AppText.caption.copyWith(
                    fontSize: 12.5,
                    color: AppColors.label2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          MiniButton(label: 'Verify', onPressed: onVerify),
        ],
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.thread,
    required this.showStar,
    required this.last,
    this.onTap,
  });

  final DemoThread thread;
  final bool showStar;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PressableRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Avatar(seedColor: thread.seed),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              thread.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyStrong.copyWith(fontSize: 16.5),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const VerifiedTick(
                            tier: VerificationTier.blue,
                            size: 15,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        thread.last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.footnote.copyWith(
                          fontSize: 14,
                          color: thread.unread > 0
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
                      thread.when,
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          // Starring is private, so the mark is quiet and it
                          // never appears on a request — you cannot shortlist
                          // a conversation that has not happened.
                          if (showStar && thread.starred)
                            const Icon(
                              Icons.star,
                              size: 15,
                              color: AppColors.accent,
                            ),
                          if (thread.unread > 0) ...[
                            const SizedBox(width: 7),
                            Container(
                              constraints:
                                  const BoxConstraints(minWidth: 20),
                              height: 20,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.fill,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${thread.unread}',
                                style: AppText.micro.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
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
