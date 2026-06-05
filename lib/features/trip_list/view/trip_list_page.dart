import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/features/trip_list/model/trip_list_item_model.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:flutter/material.dart';

class TripListPage extends StatefulWidget {
  const TripListPage({
    super.key,
    required this.dataSource,
    required this.selectedTripId,
    required this.onTripSelected,
    required this.onOpenSummary,
  });

  final TripListDataSource dataSource;
  final String selectedTripId;
  final ValueChanged<String> onTripSelected;
  final VoidCallback onOpenSummary;

  @override
  State<TripListPage> createState() => _TripListPageState();
}

class _TripListPageState extends State<TripListPage> {
  late Future<List<TripListItemModel>> _tripFuture;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _activePreferences = <String>{};

  @override
  void initState() {
    super.initState();
    _tripFuture = widget.dataSource.fetchTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _tripFuture = widget.dataSource.fetchTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TripListItemModel>>(
      future: _tripFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _TripLoadError(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final trips = snapshot.data!;
        final allPreferences =
            trips.expand((trip) => trip.preferences).toSet().toList()..sort();
        final filteredTrips = _filteredTrips(trips);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TripListHeader(onRefresh: _refresh),
            const SizedBox(height: 10),
            _FilterPanel(
              controller: _searchController,
              allPreferences: allPreferences,
              activePreferences: _activePreferences,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            _TripStats(trips: filteredTrips, totalTrips: trips.length),
            const SizedBox(height: 10),
            Expanded(
              child: filteredTrips.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      itemCount: filteredTrips.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final trip = filteredTrips[index];
                        final isSelected = trip.id == widget.selectedTripId;
                        return _TripCard(
                          trip: trip,
                          isSelected: isSelected,
                          index: index,
                          onTap: () => widget.onTripSelected(trip.id),
                          onOpenSummary: () {
                            widget.onTripSelected(trip.id);
                            widget.onOpenSummary();
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<TripListItemModel> _filteredTrips(List<TripListItemModel> trips) {
    final query = _searchController.text.trim().toLowerCase();
    return trips.where((trip) {
      final destination = '${trip.destinationName} ${trip.destinationCountry}'
          .toLowerCase()
          .contains(query);
      final notes = trip.travelNotes.toLowerCase().contains(query);
      final matchesQuery = query.isEmpty || destination || notes;
      final matchesPreferences =
          _activePreferences.isEmpty ||
          trip.preferences.any(_activePreferences.contains);
      return matchesQuery && matchesPreferences;
    }).toList();
  }
}

class _TripLoadError extends StatelessWidget {
  const _TripLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MacPanel(
        color: AppPalette.coralA(0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppPalette.coral),
            const SizedBox(height: 8),
            Text(
              'Could not load trips from the API',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripListHeader extends StatelessWidget {
  const _TripListHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Home / Trip List',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 24),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reload'),
        ),
      ],
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.controller,
    required this.allPreferences,
    required this.activePreferences,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<String> allPreferences;
  final Set<String> activePreferences;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return MacPanel(
      padding: const EdgeInsets.all(10),
      color: AppPalette.blueA(0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Search destination, country, notes',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  controller.clear();
                  activePreferences.clear();
                  onChanged();
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allPreferences.map((pref) {
              final selected = activePreferences.contains(pref);
              return FilterChip(
                label: Text(pref),
                selected: selected,
                onSelected: (value) {
                  if (value) {
                    activePreferences.add(pref);
                  } else {
                    activePreferences.remove(pref);
                  }
                  onChanged();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TripStats extends StatelessWidget {
  const _TripStats({required this.trips, required this.totalTrips});

  final List<TripListItemModel> trips;
  final int totalTrips;

  @override
  Widget build(BuildContext context) {
    final totalDays = trips
        .fold<int>(0, (sum, trip) => sum + trip.totalDays)
        .toString();
    final countries = trips.map((t) => t.destinationCountry).toSet().length;

    return MacPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppPalette.whiteA(0.78),
      child: Row(
        children: [
          Expanded(
            child: _MetricItem(
              icon: Icons.luggage_rounded,
              label: 'Trips',
              value: '${trips.length} / $totalTrips',
            ),
          ),
          _divider(),
          Expanded(
            child: _MetricItem(
              icon: Icons.calendar_month_rounded,
              label: 'Trip Days',
              value: totalDays,
            ),
          ),
          _divider(),
          Expanded(
            child: _MetricItem(
              icon: Icons.public_rounded,
              label: 'Countries',
              value: '$countries',
            ),
          ),
        ],
      ),
    );
  }
}

Widget _divider() {
  return Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: AppPalette.inkA(0.12),
  );
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppPalette.inkA(0.76)),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.58)),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripCard extends StatefulWidget {
  const _TripCard({
    required this.trip,
    required this.isSelected,
    required this.index,
    required this.onTap,
    required this.onOpenSummary,
  });

  final TripListItemModel trip;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onOpenSummary;

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _hovered;
    final stripe = _stripeColor(widget.index);
    final durationScore = (widget.trip.totalDays / 14).clamp(0.15, 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, active ? -2 : 0, 0),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [
                      stripe.withValues(alpha: 0.15),
                      AppPalette.whiteA(0),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: MacPanel(
            color: active ? AppPalette.whiteA(0.94) : null,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 112,
                  decoration: BoxDecoration(
                    color: stripe.withValues(alpha: active ? 1 : 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.trip.destinationName}, ${widget.trip.destinationCountry}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 19),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.trip.dateRangeLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.inkA(0.64),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: durationScore,
                          minHeight: 5,
                          backgroundColor: AppPalette.inkA(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(stripe),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.trip.preferences
                            .map(
                              (pref) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(pref),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.trip.travelNotes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stripe.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.trip.id,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppPalette.inkA(0.82),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: widget.onOpenSummary,
                      child: const Text('Open Summary'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _stripeColor(int index) {
    switch (index % 3) {
      case 0:
        return AppPalette.blue;
      case 1:
        return AppPalette.mint;
      default:
        return AppPalette.coral;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MacPanel(
        color: AppPalette.inkA(0.03),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 42,
              color: AppPalette.inkA(0.6),
            ),
            const SizedBox(height: 10),
            Text(
              'No trips yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Create your first trip from Add Trip.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkA(0.64)),
            ),
          ],
        ),
      ),
    );
  }
}
