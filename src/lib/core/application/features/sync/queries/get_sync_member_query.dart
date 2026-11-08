import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';

/// One device of the sync group; `null` when no such member exists.
class GetSyncMemberQuery implements IRequest<SyncMemberSummary?> {
  final String memberId;

  GetSyncMemberQuery({required this.memberId});
}

class GetSyncMemberQueryHandler implements IRequestHandler<GetSyncMemberQuery, SyncMemberSummary?> {
  final SyncMemberSummaryReader _reader;

  GetSyncMemberQueryHandler(this._reader);

  @override
  Future<SyncMemberSummary?> call(GetSyncMemberQuery request) async {
    for (final member in await _reader.readAll()) {
      if (member.memberId == request.memberId) return member;
    }
    return null;
  }
}
