import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/notifications/domain/repositories/notification_repository.dart';
import 'package:qent/features/notifications/presentation/providers/notification_providers.dart';

class NotificationController extends Notifier<NotificationState> {
  @override
  NotificationState build() {
    return NotificationState();
  }

  NotificationRepository get _repository => ref.read(notificationRepositoryProvider);

  void toggleSelectionMode() {
    state = state.copyWith(isSelectionMode: !state.isSelectionMode);
    if (!state.isSelectionMode) {
      state = state.copyWith(selectedIds: []);
    }
  }

  void toggleSelection(String notificationId) {
    final selectedIds = List<String>.from(state.selectedIds);
    if (selectedIds.contains(notificationId)) {
      selectedIds.remove(notificationId);
    } else {
      selectedIds.add(notificationId);
    }
    state = state.copyWith(selectedIds: selectedIds);
  }

  void selectAll(List<String> allIds) {
    state = state.copyWith(selectedIds: List<String>.from(allIds));
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: []);
  }

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
  }

  Future<void> markSelectedAsRead() async {
    if (state.selectedIds.isEmpty) return;
    await _repository.markMultipleAsRead(state.selectedIds);
    clearSelection();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repository.deleteNotification(notificationId);
  }

  Future<void> deleteSelected() async {
    if (state.selectedIds.isEmpty) return;
    await _repository.deleteMultipleNotifications(state.selectedIds);
    clearSelection();
  }
}

class NotificationState {
  final bool isSelectionMode;
  final List<String> selectedIds;

  NotificationState({
    this.isSelectionMode = false,
    this.selectedIds = const [],
  });

  NotificationState copyWith({
    bool? isSelectionMode,
    List<String>? selectedIds,
  }) {
    return NotificationState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

