import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/add_trip/view/add_trip_page.dart';
import 'package:api_6005cmd/features/api_demo/data/api_demo_data_source.dart';
import 'package:api_6005cmd/features/api_demo/view/api_demo_page.dart';
import 'package:api_6005cmd/features/edit_trip/data/edit_trip_data_source.dart';
import 'package:api_6005cmd/features/edit_trip/view/edit_trip_page.dart';
import 'package:api_6005cmd/features/navigation/model/app_section.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/features/trip_list/view/trip_list_page.dart';
import 'package:api_6005cmd/features/trip_summary/data/trip_summary_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/view/trip_summary_page.dart';
import 'package:flutter/material.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final TripListDataSource _tripListDataSource = TripListDataSource();
  late final TripSummaryDataSource _tripSummaryDataSource =
      TripSummaryDataSource(_tripListDataSource);
  late final EditTripDataSource _editTripDataSource =
      EditTripDataSource(_tripListDataSource);
  final ApiDemoDataSource _apiDemoDataSource = const ApiDemoDataSource();

  AppSection _section = AppSection.tripList;
  String _selectedTripId = 'trip_001';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (isWide) {
          return Scaffold(
            body: _ScaffoldBackdrop(
              section: _section,
              child: SafeArea(
                child: Row(
                  children: [
                    _DesktopSidebar(
                      section: _section,
                      onSectionChanged: _setSection,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _MainCanvas(
                          section: _section,
                          child: _buildSectionView(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Smart Travel Planner'),
          ),
          body: _ScaffoldBackdrop(
            section: _section,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _MainCanvas(
                  section: _section,
                  child: _buildSectionView(),
                ),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: AppSection.values.indexOf(_section),
            destinations: AppSection.values
                .map(
                  (section) => NavigationDestination(
                    icon: Icon(section.icon),
                    label: section.title,
                  ),
                )
                .toList(),
            onDestinationSelected: (index) {
              setState(() {
                _section = AppSection.values[index];
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionView() {
    switch (_section) {
      case AppSection.tripList:
        return TripListPage(
          dataSource: _tripListDataSource,
          selectedTripId: _selectedTripId,
          onTripSelected: (id) {
            setState(() {
              _selectedTripId = id;
            });
          },
          onOpenSummary: () {
            setState(() {
              _section = AppSection.tripSummary;
            });
          },
        );
      case AppSection.addTrip:
        return const AddTripPage();
      case AppSection.tripSummary:
        return TripSummaryPage(
          dataSource: _tripSummaryDataSource,
          tripId: _selectedTripId,
        );
      case AppSection.editTrip:
        return EditTripPage(
          dataSource: _editTripDataSource,
          tripId: _selectedTripId,
        );
      case AppSection.apiDemo:
        return ApiDemoPage(dataSource: _apiDemoDataSource);
    }
  }

  void _setSection(AppSection section) {
    setState(() {
      _section = section;
    });
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.section,
    required this.onSectionChanged,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppPalette.inkA(0.15)),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppPalette.whiteA(0.9),
                  AppPalette.blueA(0.16),
                  AppPalette.mintA(0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.blueA(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Travel Planner',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Minimalist web UI (Flutter)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppPalette.inkA(0.64),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: AppSection.values.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _SidebarNavItem(
                    entry: entry,
                    selected: section == entry,
                    onTap: () => onSectionChanged(entry),
                  ),
                );
              }).toList(),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mock mode enabled',
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.inkA(0.64),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainCanvas extends StatelessWidget {
  const _MainCanvas({
    required this.section,
    required this.child,
  });

  final AppSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MainTopBar(section: section),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(section.name),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _MainTopBar extends StatelessWidget {
  const _MainTopBar({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.inkA(0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.data_object_rounded, size: 13, color: AppPalette.blue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Data linked by Trip ID • API integration ready',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w500,
                color: AppPalette.inkA(0.84),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.blueA(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppPalette.blueA(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_rounded, size: 12, color: AppPalette.blue),
                const SizedBox(width: 5),
                Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.inkA(0.88),
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

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final AppSection entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [
                      AppPalette.blueA(widget.selected ? 0.22 : 0.14),
                      AppPalette.mintA(widget.selected ? 0.2 : 0.12),
                    ],
                  )
                : null,
            color: active ? null : AppPalette.whiteA(0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppPalette.blueA(0.32) : AppPalette.whiteA(0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.entry.icon,
                size: 19,
                color: active ? AppPalette.blue : AppPalette.inkA(0.66),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.entry.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppPalette.ink : AppPalette.inkA(0.84),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScaffoldBackdrop extends StatelessWidget {
  const _ScaffoldBackdrop({
    required this.section,
    required this.child,
  });

  final AppSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = switch (section) {
      AppSection.tripList => AppPalette.blue,
      AppSection.addTrip => AppPalette.mint,
      AppSection.tripSummary => AppPalette.coral,
      AppSection.editTrip => AppPalette.blue,
      AppSection.apiDemo => AppPalette.mint,
    };

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.white,
                  AppPalette.blueA(0.12),
                  AppPalette.mintA(0.1),
                  accent.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -120,
          top: -120,
          child: _AuraBlob(color: AppPalette.blueA(0.12), size: 340),
        ),
        Positioned(
          right: -140,
          bottom: -120,
          child: _AuraBlob(color: AppPalette.coralA(0.1), size: 360),
        ),
        child,
      ],
    );
  }
}

class _AuraBlob extends StatelessWidget {
  const _AuraBlob({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
