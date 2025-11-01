import 'package:qent/features/search/domain/models/search_filters.dart';

class SearchState {
  final SearchFilters filters;
  final bool isLoading;
  final String? error;

  SearchState({
    required this.filters,
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    SearchFilters? filters,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

