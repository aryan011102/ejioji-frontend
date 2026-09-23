import 'dart:async';

import '../core/network/api_client.dart';
import '../core/network/endpoints.dart';
import '../core/network/json.dart';
import '../shared/models/connection.dart';
import '../shared/models/enums.dart';
import '../shared/models/tile.dart';

/// Connecting a source, and watching the one pull it gets.
///
/// Data is fetched exactly once, when the source is connected. There is no
/// background sync to fall back on, which is why the wait is a screen the
/// client polls rather than something that quietly catches up later.
class SourcesRepository {
  const SourcesRepository(this._api);

  final ApiClient _api;

  Future<List<Connection>> connections() async =>
      Connection.listFrom(await _api.getList(Api.connections));

  /// Step one of a Google source: ask for a URL to send the person to.
  ///
  /// This fails with a 403 if the matching consent purpose is not open, which
  /// is deliberate: consent is checked before anyone sees Google's screen,
  /// not after.
  Future<Authorization> authorize(SourceProvider provider) async {
    final body = await _api.post(Api.authorize(provider.wire));
    return Authorization.fromJson(body);
  }

  /// Step two: hand back what Google returned.
  ///
  /// The app completes the flow with its own bearer token, and the state is
  /// bound to both the user who began it and the source they began it for.
  /// A callback anyone could complete would let an attacker have a victim
  /// finish the attacker's flow.
  Future<ConnectResult> complete(
    SourceProvider provider, {
    String? code,
    String? state,
    String? error,
  }) async {
    final body = await _api.post(
      Api.complete(provider.wire),
      body: {
        if (state != null) 'state': state,
        if (code != null) 'code': code,
        if (error != null) 'error': error,
      },
    );
    return ConnectResult.fromJson(body);
  }

  /// Apple Music, step one: a short-lived developer token for MusicKit. The
  /// same consent rule as a Google source: a 403 until apple_music_import is
  /// open, so nobody sees Apple's prompt before ours.
  Future<String> appleMusicDeveloperToken() async {
    final body = await _api.post(Api.authorize(SourceProvider.appleMusic.wire));
    return body.str('developer_token');
  }

  /// Apple Music, step two: the Music User Token MusicKit gave back, or
  /// [error] when it gave none. The server opens a run and reads the library
  /// once; there is no redirect and so no state to carry.
  Future<ConnectResult> completeAppleMusic({
    String? userToken,
    String? error,
  }) async {
    final body = await _api.post(
      Api.complete(SourceProvider.appleMusic.wire),
      body: {
        if (userToken != null) 'music_user_token': userToken,
        if (error != null) 'error': error,
      },
    );
    return ConnectResult.fromJson(body);
  }

  /// Netflix has no API. The person downloads their own per-profile viewing
  /// activity and the CSV is posted as the request body: it is parsed in
  /// memory and never written to storage.
  Future<IngestionRun> uploadNetflix(String csv) async {
    final body = await _api.postRaw(
      Api.netflixUpload,
      body: csv,
      contentType: 'text/csv',
    );
    return IngestionRun.fromJson(body);
  }

  /// Spotify, from the person's own data download: one JSON array of plays.
  /// Several files are joined into one array before this is called. Any
  /// element that is not a play refuses the whole body on the server, so
  /// nothing else from the download (address, payments) can ride along.
  Future<IngestionRun> uploadSpotify(String json) async {
    final body = await _api.postRaw(
      Api.spotifyUpload,
      body: json,
      contentType: 'application/json',
    );
    return IngestionRun.fromJson(body);
  }

  Future<IngestionRun> run(String runId) async =>
      IngestionRun.fromJson(await _api.getJson(Api.run(runId)));

  /// Polls a run until it reaches a terminal state.
  ///
  /// The interval is deliberately unhurried: a pull takes a minute or more,
  /// and a tighter loop would only cost battery. [onUpdate] fires on every
  /// read so the checklist can move while it waits.
  Future<IngestionRun> watch(
    String runId, {
    void Function(IngestionRun)? onUpdate,
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (true) {
      final current = await run(runId);
      onUpdate?.call(current);
      if (current.isFinished) return current;

      if (DateTime.now().isAfter(deadline)) return current;
      await Future<void>.delayed(interval);
    }
  }

  /// Every tile the server has computed for this person, picked or not.
  Future<List<Insight>> candidates() async =>
      Insight.listFrom(await _api.getList(Api.insightCandidates));

  /// Asks the model for a fresh batch. Capped per day, because each press is
  /// a paid call, and refused outright without AI consent.
  Future<MoreTiles> more() async =>
      MoreTiles.fromJson(await _api.post(Api.insightsMore));
}

/// The answer to "show me more".
class MoreTiles {
  const MoreTiles({required this.status, required this.added});

  final String status;
  final List<Insight> added;

  bool get succeeded => status == 'succeeded';

  /// The model was asked and came back with nothing usable, or is not
  /// reachable. Neither is the person's problem, and neither is an error
  /// worth a red screen.
  bool get failed => status == 'failed' || status == 'unavailable';

  /// Nothing left to propose from the data we hold.
  bool get refused => status == 'refused';

  String get message => switch (status) {
        'succeeded' => 'Added ${added.length} more',
        'refused' => 'Nothing new to add from what we have yet',
        _ => 'Could not get more just now. Try again later.',
      };

  static MoreTiles fromJson(Json j) => MoreTiles(
        status: j.strOrNull('status') ?? 'failed',
        added: Insight.listFrom(j.objects('added')),
      );
}
