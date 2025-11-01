import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/search/presentation/controllers/search_controller.dart';
import 'package:qent/features/search/presentation/controllers/search_state.dart';
import 'package:qent/features/search/presentation/controllers/filter_options_controller.dart';
import 'package:qent/features/search/presentation/controllers/filter_options_state.dart';

/// Provider for search controller
final searchControllerProvider = NotifierProvider<SearchController, SearchState>(
  () => SearchController(),
);

/// Provider for filter options controller
final filterOptionsControllerProvider = NotifierProvider<FilterOptionsController, FilterOptionsState>(
  () => FilterOptionsController(),
);

