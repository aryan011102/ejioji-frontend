import 'package:flutter/foundation.dart';

import '../../core/network/json.dart';
import 'enums.dart';

/// One step of a pull, as the client-polled checklist shows it.
@immutable
class RunStep {
  const RunStep({
    required this.name,
    required this.status,
    required this.itemCount,
  });

  final String name;
  final StepStatus status;
  final int itemCount;

  static RunStep fromJson(Json j) => RunStep(
        name: j.str('name'),
        status: StepStatus.parse(j.strOrNull('status')),
        itemCount: j.intOr('item_count', 0),
      );
}

/// A single pull of one source.
///
/// All provider data is fetched once, at connect time. There is no sync: the
/// access token lives only in the worker's memory for the couple of minutes
/// this takes, and is revoked when it ends. That is why the onboarding wait is
/// a real screen rather than a spinner nobody sees.
@immutable
class IngestionRun {
  const IngestionRun({
    required this.id,
    required this.provider,
    required this.providerAccountId,
    required this.runSeq,
    required this.reason,
    required this.status,
    required this.steps,
    required this.startedAt,
    this.failureCode,
    this.sufficiency,
    this.finishedAt,
  });

  final String id;
  final SourceProvider provider;
  final String providerAccountId;

  /// 1 on the initial connect; a refresh is simply a second one-time fetch
  /// under a fresh grant.
  final int runSeq;

  final String reason;
  final RunStatus status;
  final FailureCode? failureCode;

  /// How much came back. Thin is not a failure: the UI says what it found.
  final Sufficiency? sufficiency;

  final List<RunStep> steps;
  final DateTime startedAt;
  final DateTime? finishedAt;

  bool get isFinished => status.isTerminal;

  bool get isRunning => !status.isTerminal;

  /// Rough progress for the onboarding meter, so the wait has a shape.
  double get progress {
    if (steps.isEmpty) return isFinished ? 1 : 0;
    final done = steps
        .where((s) => s.status == StepStatus.done || s.status == StepStatus.failed)
        .length;
    return done / steps.length;
  }

  int get itemsFound =>
      steps.fold(0, (total, s) => total + s.itemCount);

  /// What to tell someone when a pull ends without usable data. Never "an
  /// error occurred": each of these has a way forward.
  String? get problem => switch (failureCode) {
        null => null,
        FailureCode.interrupted =>
          'That stopped partway. Connect again when you have a minute.',
        FailureCode.providerError =>
          '${provider.label} was not answering. Try again in a bit.',
        FailureCode.quotaExhausted =>
          'We have hit our limit with ${provider.label} for today. Try tomorrow.',
        FailureCode.accessRevoked =>
          'Access to ${provider.label} was withdrawn before we finished.',
        FailureCode.consentWithdrawn =>
          'You withdrew permission while this was running, so nothing was kept.',
        FailureCode.internal || FailureCode.unknown =>
          'Something broke on our side. It is not you.',
      };

  static IngestionRun fromJson(Json j) => IngestionRun(
        id: j.str('id'),
        provider: SourceProvider.parse(j.strOrNull('provider')),
        providerAccountId: j.str('provider_account_id'),
        runSeq: j.intOr('run_seq', 1),
        reason: j.strOrNull('reason') ?? 'initial',
        status: RunStatus.parse(j.strOrNull('status')),
        failureCode: j['failure_code'] == null
            ? null
            : FailureCode.parse(j.strOrNull('failure_code')),
        sufficiency: j['sufficiency'] == null
            ? null
            : Sufficiency.parse(j.strOrNull('sufficiency')),
        steps: j.objects('steps').map(RunStep.fromJson).toList(growable: false),
        startedAt: j.time('started_at'),
        finishedAt: j.timeOrNull('finished_at'),
      );
}

/// A linked provider account.
@immutable
class Connection {
  const Connection({
    required this.id,
    required this.provider,
    required this.status,
    required this.scopes,
    required this.connectedAt,
    this.disconnectedAt,
    this.latestRun,
  });

  final String id;
  final SourceProvider provider;
  final ProviderStatus status;
  final List<String> scopes;
  final DateTime connectedAt;
  final DateTime? disconnectedAt;
  final IngestionRun? latestRun;

  bool get isActive => status == ProviderStatus.active;

  static Connection fromJson(Json j) {
    final run = j.objectOrNull('latest_run');
    return Connection(
      id: j.str('id'),
      provider: SourceProvider.parse(j.strOrNull('provider')),
      status: ProviderStatus.parse(j.strOrNull('status')),
      scopes: j.strings('scopes'),
      connectedAt: j.time('connected_at'),
      disconnectedAt: j.timeOrNull('disconnected_at'),
      latestRun: run == null ? null : IngestionRun.fromJson(run),
    );
  }

  static List<Connection> listFrom(List<Json> items) =>
      items.map(Connection.fromJson).toList(growable: false);
}

/// Where to send the person for consent, and the state that ties the answer
/// back to them.
@immutable
class Authorization {
  const Authorization({
    required this.url,
    required this.state,
    required this.expiresIn,
  });

  final String url;

  /// Bound to this user and this source, and single use. It is what stops
  /// someone finishing an attacker's flow.
  final String state;

  final Duration expiresIn;

  static Authorization fromJson(Json j) => Authorization(
        url: j.str('authorization_url'),
        state: j.str('state'),
        expiresIn: Duration(seconds: j.intOr('expires_in_seconds', 600)),
      );
}

/// What came back after the consent screen. Declining is not an error.
@immutable
class ConnectResult {
  const ConnectResult({required this.declined, this.run});

  final bool declined;
  final IngestionRun? run;

  static ConnectResult fromJson(Json j) {
    final run = j.objectOrNull('run');
    return ConnectResult(
      declined: j.strOrNull('status') == 'declined',
      run: run == null ? null : IngestionRun.fromJson(run),
    );
  }
}
