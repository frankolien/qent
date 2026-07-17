import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/countries/presentation/pages/country_picker_page.dart';
import 'package:qent/features/discovery/domain/models/car_search_hit.dart';
import 'package:qent/features/discovery/presentation/providers/discovery_providers.dart';

/// V2 §7 — primary discovery screen. Hits /api/cars/search filtered
/// by the user's saved country. Minimum-filter version for Week 1; the
/// full §7.7 filter sheet (transmission, fuel, instant-book, distance)
/// lands in Week 5.
class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage> {
  String _sortBy = 'rating';
  String? _city;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final country = user?.country;

    if (country == null || country.trim().isEmpty) {
      return Scaffold(
        backgroundColor: QentColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pick your country first',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CountryPickerPage(dismissible: true),
                  ),
                ),
                child: const Text('Choose country'),
              ),
            ],
          ),
        ),
      );
    }

    final query = DiscoveryQuery(
      country: country,
      city: _city,
      sortBy: _sortBy,
    );
    final asyncCars = ref.watch(discoverySearchProvider(query));

    return Scaffold(
      backgroundColor: QentColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: QentColors.accent,
          onRefresh: () async {
            ref.invalidate(discoverySearchProvider(query));
            await ref.read(discoverySearchProvider(query).future);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(country)),
              SliverToBoxAdapter(child: _buildSortBar()),
              asyncCars.when(
                data: (cars) => cars.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        sliver: SliverList.separated(
                          itemCount: cars.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (_, i) => _CarCard(hit: cars[i]),
                        ),
                      ),
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: QentColors.accent),
                  ),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load cars.\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: QentColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String country) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discover',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CountryPickerPage(dismissible: true),
              ),
            ),
            child: Row(
              children: [
                Text(
                  country.toUpperCase(),
                  style: const TextStyle(
                    color: QentColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: QentColors.accent,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    final sorts = const [
      ('rating', 'Best rated'),
      ('price_asc', 'Price ↑'),
      ('price_desc', 'Price ↓'),
      ('newest', 'Newest'),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: sorts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (key, label) = sorts[i];
          final selected = key == _sortBy;
          return GestureDetector(
            onTap: () => setState(() => _sortBy = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : QentColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final CarSearchHit hit;
  const _CarCard({required this.hit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QentColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: hit.photos.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: hit.photos.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: QentColors.surfaceLight),
                    errorWidget: (_, __, ___) => Container(
                      color: QentColors.surfaceLight,
                      child: const Icon(
                        Icons.directions_car,
                        color: QentColors.textMuted,
                        size: 48,
                      ),
                    ),
                  )
                : Container(
                    color: QentColors.surfaceLight,
                    child: const Icon(
                      Icons.directions_car,
                      color: QentColors.textMuted,
                      size: 48,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${hit.make} ${hit.model}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hit.instantBook)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: QentColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Instant',
                          style: TextStyle(
                            color: QentColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if ((hit.rating ?? 0) > 0) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        hit.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      if ((hit.tripCount ?? 0) > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${hit.tripCount} trips)',
                          style: const TextStyle(
                            color: QentColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      const Text(
                        '·',
                        style: TextStyle(color: QentColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        hit.city.isNotEmpty ? hit.city : hit.location,
                        style: const TextStyle(
                          color: QentColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '\$${hit.pricePerDayUsdc.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: ' USDC / day',
                        style: TextStyle(
                          color: QentColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 56,
              color: QentColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No cars yet in your country.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back soon — we\'re onboarding hosts.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
