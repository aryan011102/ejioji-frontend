import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../shared/models/enums.dart';

/// Reporting.
///
/// A report always blocks: there is never a "reported but still chatting"
/// state to secure. It can only be aimed at someone the reporter actually came
/// across, and anyone else answers the same 404 as a person who is simply
/// unavailable, so a report cannot be aimed at an id picked off a list.
class TrustRepository {
  const TrustRepository(this._api);

  final ApiClient _api;

  /// Files a report and blocks in the same call.
  ///
  /// [messageIds] cite what the report is about. Only the ids travel: the
  /// message text is never copied into the report, because there is one copy
  /// of a conversation and it is the conversation.
  Future<String> report({
    required String userId,
    required ReportReason reason,
    String? note,
    List<String> messageIds = const [],
  }) async {
    final body = await _api.post(
      Api.reports,
      body: {
        'user_id': userId,
        'reason': reason.wire,
        if (note != null && note.isNotEmpty) 'note': note,
        if (messageIds.isNotEmpty) 'message_ids': messageIds,
      },
    );
    return body.str('id');
  }
}
