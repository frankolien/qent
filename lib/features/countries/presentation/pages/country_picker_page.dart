import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/theme/app_theme.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/countries/domain/models/country.dart';
import 'package:qent/features/countries/presentation/providers/countries_providers.dart';

/// V2 §6.3 — country picker shown right after sign-in. Supported
/// markets land users straight into discovery; waitlist markets show
/// a "join the waitlist" panel (no V1 fallback because V2 doesn't
/// share infrastructure with the legacy NG-only flow).
class CountryPickerPage extends ConsumerStatefulWidget {
  final VoidCallback? onCountrySelected;
  final bool dismissible;

  const CountryPickerPage({
    super.key,
    this.onCountrySelected,
    this.dismissible = false,
  });

  @override
  ConsumerState<CountryPickerPage> createState() => _CountryPickerPageState();
}

class _CountryPickerPageState extends ConsumerState<CountryPickerPage> {
  String _query = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final asyncCountries = ref.watch(countriesListProvider);

    return Scaffold(
      backgroundColor: QentColors.background,
      appBar: AppBar(
        backgroundColor: QentColors.background,
        elevation: 0,
        leading: widget.dismissible
            ? const BackButton(color: Colors.white)
            : null,
        automaticallyImplyLeading: widget.dismissible,
        title: const Text(
          'Where are you?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'Pick your country so we can show local cars and currency.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search countries',
                  hintStyle: const TextStyle(color: QentColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: QentColors.textMuted,
                  ),
                  filled: true,
                  fillColor: QentColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: asyncCountries.when(
                data: (countries) => _buildList(countries),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: QentColors.accent),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load countries.\n$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: QentColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => ref.invalidate(countriesListProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Country> all) {
    final filtered = _query.isEmpty
        ? all
        : all
            .where((c) =>
                c.name.toLowerCase().contains(_query) ||
                c.iso2.toLowerCase().contains(_query))
            .toList();

    final supported = filtered.where((c) => c.supported).toList();
    final waitlist = filtered.where((c) => !c.supported).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (supported.isNotEmpty) ...[
          _sectionHeader('Available now'),
          ...supported.map((c) => _countryTile(c, enabled: true)),
        ],
        if (waitlist.isNotEmpty) ...[
          _sectionHeader('Coming soon'),
          ...waitlist.map((c) => _countryTile(c, enabled: false)),
        ],
        if (supported.isEmpty && waitlist.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No countries match "$_query".',
                style: const TextStyle(color: QentColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _countryTile(Country c, {required bool enabled}) {
    return InkWell(
      onTap: enabled && !_saving ? () => _pick(c) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(
              c.flagEmoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: TextStyle(
                      color: enabled
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enabled
                        ? '${c.currencyCode} · ${c.phoneCode}'
                        : 'Join the waitlist',
                    style: const TextStyle(
                      color: QentColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right, color: QentColors.textMuted)
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                    color: QentColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(Country c) async {
    setState(() => _saving = true);
    try {
      final ds = ref.read(countriesDataSourceProvider);
      await ds.setMyCountry(c.iso2);
      // Pull the freshly-saved country back into AuthState. When the
      // picker is the gate's current child (not dismissible), this
      // state change alone makes `_AuthGate.build` swap to
      // MainNavPage — we MUST NOT navigate manually here, otherwise
      // we race with the gate's rebuild and stack home twice.
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      widget.onCountrySelected?.call();
      if (widget.dismissible && Navigator.canPop(context)) {
        Navigator.of(context).pop(c);
      }
      // Non-dismissible: do nothing — let _AuthGate re-render.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: QentColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
