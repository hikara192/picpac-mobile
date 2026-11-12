import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class PreflightAckState {
  const PreflightAckState([this._revisions = const <String, int>{}]);

  final Map<String, int> _revisions;

  int? revisionOf(String designId) => _revisions[designId];

  bool covers(String designId, int revision) =>
      (_revisions[designId] ?? -1) >= revision;

  PreflightAckState withAck(String designId, int revision) =>
      PreflightAckState(<String, int>{..._revisions, designId: revision});

  PreflightAckState without(String designId) => PreflightAckState(<String, int>{
    for (final entry in _revisions.entries)
      if (entry.key != designId) entry.key: entry.value,
  });
}

bool isPreflightBlocked(Failure failure) =>
    failure.code == preflightBlockedCode;

const String preflightBlockedCode = 'preflight_blocked';

String? preflightBlockedDesignId(Failure failure) {
  final fields = failure is ApiFailure
      ? failure.fieldErrors
      : const <String, String>{};
  for (final key in fields.keys) {
    if (key.startsWith('lines.') && key.length > 'lines.'.length) {
      return key.substring('lines.'.length);
    }
  }
  return null;
}

final class PreflightAckStore extends Notifier<PreflightAckState> {
  @override
  PreflightAckState build() => const PreflightAckState();

  void acknowledge(String designId, int revision) {
    state = state.withAck(designId, revision);
  }

  bool covers(String designId, int? revision) =>
      revision != null && state.covers(designId, revision);

  void forget(String designId) => state = state.without(designId);

  void clear() => state = const PreflightAckState();
}

final preflightAckProvider =
    NotifierProvider<PreflightAckStore, PreflightAckState>(
      PreflightAckStore.new,
    );
