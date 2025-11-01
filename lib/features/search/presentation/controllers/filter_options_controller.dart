import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/search/domain/models/filter_options.dart';
import 'package:qent/features/search/presentation/controllers/filter_options_state.dart';

/// Controller for managing filter options (will be loaded from Firebase later)
class FilterOptionsController extends Notifier<FilterOptionsState> {
  @override
  FilterOptionsState build() {
    // Initialize with default options
    // TODO: Replace with Firebase data loading
    return FilterOptionsState(
      options: FilterOptions.defaultOptions(),
    );
  }

  Future<void> loadFilterOptions() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // TODO: Implement Firebase loading
      // final options = await filterOptionsRepository.getFilterOptions();
      
      // For now, use default options
      final options = FilterOptions.defaultOptions();
      
      state = state.copyWith(
        options: options,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

