/// Направление синхронизации при сравнении меток времени.
enum SyncDirection { push, pull, upToDate }

SyncDirection resolveSyncDirection({
  required DateTime localUpdated,
  required DateTime? remoteUpdated,
}) {
  if (remoteUpdated == null) return SyncDirection.push;
  if (remoteUpdated.isAfter(localUpdated)) return SyncDirection.pull;
  if (localUpdated.isAfter(remoteUpdated)) return SyncDirection.push;
  return SyncDirection.upToDate;
}
