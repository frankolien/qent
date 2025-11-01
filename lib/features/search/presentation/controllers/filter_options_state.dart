import 'package:qent/features/search/domain/models/filter_options.dart';

class FilterOptionsState {
  final FilterOptions options;
  final bool isLoading;
  final String? error;

  FilterOptionsState({
    required this.options,
    this.isLoading = false,
    this.error,
  });

  FilterOptionsState copyWith({
    FilterOptions? options,
    bool? isLoading,
    String? error,
  }) {
    return FilterOptionsState(
      options: options ?? this.options,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

