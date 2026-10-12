import '../session_types.dart';

SessionState applySessionOps(
  SessionState state,
  List<Map<String, dynamic>> ops,
) {
  final slots = {for (final slot in state.slots) slot.id: slot};
  for (final op in ops) {
    final operation = op['op'] as String?;
    if (operation == 'addSlot' && op['slot'] is Map) {
      final slot = SessionSlot.fromJson(
        Map<String, dynamic>.from(op['slot'] as Map),
      );
      slots[slot.id] = slot;
    } else if (operation == 'updateSlot' && op['slot'] is Map) {
      final slot = SessionSlot.fromJson(
        Map<String, dynamic>.from(op['slot'] as Map),
      );
      slots[slot.id] = slot;
    } else if (operation == 'removeSlot') {
      final id = op['slot_id'] as String? ?? op['slotId'] as String?;
      if (id != null) slots.remove(id);
    } else if (operation == 'setSlots' && op['slots'] is List) {
      slots.clear();
      for (final item in op['slots'] as List) {
        if (item is Map) {
          final slot = SessionSlot.fromJson(Map<String, dynamic>.from(item));
          slots[slot.id] = slot;
        }
      }
    }
  }
  return state.copyWith(slots: slots.values.toList());
}

bool isSlotFull(
  PlatformSession session,
  String slotId, {
  String? excludeRequestId,
}) {
  final active = session.requests.where(
    (request) =>
        request.slotId == slotId &&
        (request.status == SessionBookingRequestStatus.pending ||
            request.status == SessionBookingRequestStatus.confirmed) &&
        request.id != excludeRequestId,
  );
  return active.length >= session.slotCapacity;
}
