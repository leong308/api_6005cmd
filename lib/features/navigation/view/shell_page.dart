import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/core/api/api_client.dart';
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
  final ApiClient _apiClient = ApiClient();
  late final TripListDataSource _tripListDataSource = TripListDataSource(
    apiClient: _apiClient,
  );
  late final TripSummaryDataSource _tripSummaryDataSource =
      TripSummaryDataSource(_tripListDataSource);
  late final EditTripDataSource _editTripDataSource = EditTripDataSource(
    _tripListDataSource,
  );
  final ApiDemoDataSource _apiDemoDataSource = const ApiDemoDataSource();

  AppSection _section = AppSection.tripList;
  String _selectedTripId = '';
  _AuthenticatedUser? _user;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (_user == null) {
          return Scaffold(
            body: _ScaffoldBackdrop(
              section: AppSection.tripList,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: _AuthGate(
                      apiClient: _apiClient,
                      onAuthenticated: _handleAuthenticated,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (isWide) {
          return Scaffold(
            body: _ScaffoldBackdrop(
              section: _section,
              child: SafeArea(
                child: Row(
                  children: [
                    _DesktopSidebar(
                      section: _section,
                      user: _user!,
                      onLogout: _logout,
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
            actions: [
              IconButton(
                tooltip: 'Logout',
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
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
        return AddTripPage(
          dataSource: _tripListDataSource,
          onTripCreated: (id) {
            setState(() {
              _selectedTripId = id;
              _section = AppSection.tripSummary;
            });
          },
        );
      case AppSection.tripSummary:
        return TripSummaryPage(
          dataSource: _tripSummaryDataSource,
          tripId: _selectedTripId,
          onEditTrip: () {
            setState(() {
              _section = AppSection.editTrip;
            });
          },
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

  void _handleAuthenticated(_AuthenticatedUser user, String token) {
    _apiClient.setAuthToken(token);
    _tripListDataSource.clearKnownTrips();
    setState(() {
      _user = user;
      _selectedTripId = '';
      _section = AppSection.tripList;
    });
  }

  void _logout() {
    _apiClient.setAuthToken(null);
    _tripListDataSource.clearKnownTrips();
    setState(() {
      _user = null;
      _selectedTripId = '';
      _section = AppSection.tripList;
    });
  }
}

class _AuthenticatedUser {
  const _AuthenticatedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
  });

  final String id;
  final String name;
  final String email;
  final bool emailVerified;

  factory _AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return _AuthenticatedUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      emailVerified: json['emailVerified'] == true,
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.apiClient, required this.onAuthenticated});

  final ApiClient apiClient;
  final void Function(_AuthenticatedUser user, String token) onAuthenticated;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  String _message = '';
  String _devVerificationUrl = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.whiteA(0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.blueA(0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _registerMode ? 'Create Account' : 'Login',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _registerMode
                    ? 'Verify your email before logging in.'
                    : 'Use your verified email account to continue.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
              ),
              const SizedBox(height: 16),
              if (_registerMode) ...[
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _registerMode ? _register() : _login(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _message,
                  style: TextStyle(
                    color:
                        _message.toLowerCase().contains('success') ||
                            _message.toLowerCase().contains('verify')
                        ? AppPalette.mint
                        : AppPalette.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_devVerificationUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _devVerificationUrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : _registerMode
                    ? _register
                    : _login,
                icon: Icon(
                  _registerMode
                      ? Icons.mark_email_read_rounded
                      : Icons.login_rounded,
                ),
                label: Text(_registerMode ? 'Sign Up' : 'Login'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _registerMode = !_registerMode;
                          _message = '';
                          _devVerificationUrl = '';
                        });
                      },
                child: Text(
                  _registerMode
                      ? 'Already verified? Login'
                      : 'Need an account? Sign up',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    await _runAuthAction(() async {
      final response = await widget.apiClient.postJson('/auth/login', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
      final token = response['token']?.toString() ?? '';
      final data = _asMap(response['data']);
      if (token.isEmpty) {
        throw const ApiException(500, 'Login did not return a token.');
      }
      widget.onAuthenticated(_AuthenticatedUser.fromJson(data), token);
    });
  }

  Future<void> _register() async {
    await _runAuthAction(() async {
      final response = await widget.apiClient.postJson('/auth/register', {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
      final emailVerification = _asMap(response['emailVerification']);
      setState(() {
        _message =
            response['message']?.toString() ??
            'Registration success. Verify your email before logging in.';
        _devVerificationUrl =
            emailVerification['devVerificationUrl']?.toString() ?? '';
        _registerMode = false;
      });
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = '';
      _devVerificationUrl = '';
    });
    try {
      await action();
    } on ApiException catch (error) {
      setState(() {
        _message = error.message;
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.section,
    required this.user,
    required this.onLogout,
    required this.onSectionChanged,
  });

  final AppSection section;
  final _AuthenticatedUser user;
  final VoidCallback onLogout;
  final ValueChanged<AppSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppPalette.inkA(0.15))),
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
                const SizedBox(height: 8),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.inkA(0.64),
                    fontWeight: FontWeight.w600,
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _MainCanvas extends StatelessWidget {
  const _MainCanvas({required this.section, required this.child});

  final AppSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(section.name), child: child),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
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
  const _ScaffoldBackdrop({required this.section, required this.child});

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
  const _AuraBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
