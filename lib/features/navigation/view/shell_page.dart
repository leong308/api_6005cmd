import 'dart:async';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/core/api/api_client.dart';
import 'package:api_6005cmd/features/add_trip/view/add_trip_page.dart';
import 'package:api_6005cmd/features/api_demo/data/api_demo_data_source.dart';
import 'package:api_6005cmd/features/api_demo/view/api_demo_page.dart';
import 'package:api_6005cmd/features/edit_trip/data/edit_trip_data_source.dart';
import 'package:api_6005cmd/features/edit_trip/view/edit_trip_page.dart';
import 'package:api_6005cmd/features/navigation/model/app_section.dart';
import 'package:api_6005cmd/features/navigation/view/first_login_tour.dart';
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
  final AppTourOverlayController _tourController = AppTourOverlayController();
  final GlobalKey _tourAppIdentityKey = GlobalKey(
    debugLabel: 'tour-app-identity',
  );
  final GlobalKey _tourMainCanvasKey = GlobalKey(
    debugLabel: 'tour-main-canvas',
  );
  final GlobalKey _tourLogoutKey = GlobalKey(debugLabel: 'tour-logout');
  late final Map<AppSection, GlobalKey> _tourSectionKeys = {
    for (final section in AppSection.values)
      section: GlobalKey(debugLabel: 'tour-${section.name}-navigation'),
  };

  AppSection _section = AppSection.tripList;
  String _selectedTripId = '';
  _AuthenticatedUser? _user;

  @override
  void dispose() {
    _tourController.dispose();
    super.dispose();
  }

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
                      appIdentityKey: _tourAppIdentityKey,
                      sectionKeys: _tourSectionKeys,
                      logoutKey: _tourLogoutKey,
                      section: _section,
                      user: _user!,
                      onLogout: _logout,
                      onSectionChanged: _setSection,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: KeyedSubtree(
                          key: _tourMainCanvasKey,
                          child: _MainCanvas(
                            section: _section,
                            child: _buildSectionView(),
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

        return Scaffold(
          appBar: AppBar(
            title: Text('Smart Travel Planner', key: _tourAppIdentityKey),
            actions: [
              IconButton(
                key: _tourLogoutKey,
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
                child: KeyedSubtree(
                  key: _tourMainCanvasKey,
                  child: _MainCanvas(
                    section: _section,
                    child: _buildSectionView(),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: AppSection.values.indexOf(_section),
            destinations: AppSection.values
                .map(
                  (section) => NavigationDestination(
                    key: _tourSectionKeys[section],
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
    _maybeStartFirstLoginTour(user);
  }

  void _logout() {
    _tourController.cancel();
    _apiClient.setAuthToken(null);
    _tripListDataSource.clearKnownTrips();
    setState(() {
      _user = null;
      _selectedTripId = '';
      _section = AppSection.tripList;
    });
  }

  void _maybeStartFirstLoginTour(_AuthenticatedUser user) {
    if (!user.firstLogin) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _user?.id != user.id || _user?.email != user.email) {
        return;
      }
      unawaited(
        _tourController.start(
          context: context,
          steps: _buildFirstLoginTourSteps(),
          onComplete: () => _finishFirstLoginTour(restoreHome: true),
          onSkip: () => _finishFirstLoginTour(restoreHome: true),
        ),
      );
    });
  }

  List<AppTourStep> _buildFirstLoginTourSteps() {
    return [
      AppTourStep(
        targetKey: _tourAppIdentityKey,
        title: 'Smart Travel Planner',
        description:
            'Use this workspace to manage trips, generate summaries, and test API coverage.',
        beforeShow: () => _prepareTourSection(AppSection.tripList),
      ),
      _navigationTourStep(
        AppSection.tripList,
        'Return here to browse trips, search filters, and open a selected summary.',
      ),
      _sectionTourStep(
        AppSection.tripList,
        'Home / Trip List',
        'Search and preference chips narrow the trip list before opening a trip.',
      ),
      _navigationTourStep(
        AppSection.addTrip,
        'Create a trip with dates, preferences, notes, and a pinned location.',
      ),
      _sectionTourStep(
        AppSection.addTrip,
        'Add Trip',
        'The form builds a POST payload and validates dates before submission.',
      ),
      _navigationTourStep(
        AppSection.tripSummary,
        'Review weather, agenda, recommendations, routes, and JSON output here.',
      ),
      _sectionTourStep(
        AppSection.tripSummary,
        'Trip Summary',
        'Select a trip first; this page then shows combined external data.',
      ),
      _navigationTourStep(
        AppSection.editTrip,
        'Edit an existing record after choosing a trip from Home.',
      ),
      _sectionTourStep(
        AppSection.editTrip,
        'Edit Trip',
        'This interface updates trip fields and previews the PUT payload.',
      ),
      _navigationTourStep(
        AppSection.apiDemo,
        'Inspect backend and external endpoint coverage here.',
      ),
      _sectionTourStep(
        AppSection.apiDemo,
        'Testing / API Demo',
        'Use this section when checking API base URLs and endpoint groups.',
      ),
      AppTourStep(
        targetKey: _tourLogoutKey,
        title: 'Logout',
        description: 'Sign out here when you are finished.',
        beforeShow: () => _prepareTourSection(AppSection.tripList),
      ),
    ];
  }

  AppTourStep _navigationTourStep(AppSection section, String description) {
    return AppTourStep(
      targetKey: _tourSectionKeys[section]!,
      title: section.title,
      description: description,
      beforeShow: () => _prepareTourSection(section),
    );
  }

  AppTourStep _sectionTourStep(
    AppSection section,
    String title,
    String description,
  ) {
    return AppTourStep(
      targetKey: _tourMainCanvasKey,
      title: title,
      description: description,
      beforeShow: () => _prepareTourSection(section),
    );
  }

  Future<void> _prepareTourSection(AppSection section) async {
    if (!mounted) {
      return;
    }
    if (_section != section) {
      setState(() {
        _section = section;
      });
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 260));
  }

  void _finishFirstLoginTour({required bool restoreHome}) {
    if (restoreHome &&
        mounted &&
        _user != null &&
        _section != AppSection.tripList) {
      setState(() {
        _section = AppSection.tripList;
      });
    }
    if (_user != null) {
      unawaited(
        _apiClient
            .postJson('/auth/complete-tour', {})
            .catchError((_) => <String, dynamic>{}),
      );
    }
  }
}

class _AuthenticatedUser {
  const _AuthenticatedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.firstLogin,
  });

  final String id;
  final String name;
  final String email;
  final bool emailVerified;
  final bool firstLogin;

  factory _AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return _AuthenticatedUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      emailVerified: json['emailVerified'] == true,
      firstLogin: json['firstLogin'] != false,
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
  bool _forgotPasswordMode = false;
  bool _busy = false;
  String _message = '';
  String _devActionUrl = '';

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
                _forgotPasswordMode
                    ? 'Reset Password'
                    : _registerMode
                    ? 'Create Account'
                    : 'Login',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _forgotPasswordMode
                    ? 'Enter your email and we will send a reset link.'
                    : _registerMode
                    ? 'Verify your email before logging in.'
                    : 'Use your verified email account to continue.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
              ),
              const SizedBox(height: 16),
              if (_registerMode && !_forgotPasswordMode) ...[
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
                textInputAction: _forgotPasswordMode
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) {
                  if (_forgotPasswordMode) {
                    _requestPasswordReset();
                  }
                },
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (!_forgotPasswordMode) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _registerMode ? _register() : _login(),
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
              ],
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _message,
                  style: TextStyle(
                    color: _isPositiveMessage(_message)
                        ? AppPalette.mint
                        : AppPalette.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_devActionUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _devActionUrl,
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
                    : _forgotPasswordMode
                    ? _requestPasswordReset
                    : _registerMode
                    ? _register
                    : _login,
                icon: Icon(
                  _forgotPasswordMode
                      ? Icons.lock_reset_rounded
                      : _registerMode
                      ? Icons.mark_email_read_rounded
                      : Icons.login_rounded,
                ),
                label: Text(
                  _forgotPasswordMode
                      ? 'Send Reset Link'
                      : _registerMode
                      ? 'Sign Up'
                      : 'Login',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          if (_forgotPasswordMode) {
                            _forgotPasswordMode = false;
                            _registerMode = false;
                          } else {
                            _registerMode = !_registerMode;
                          }
                          _message = '';
                          _devActionUrl = '';
                        });
                      },
                child: Text(
                  _forgotPasswordMode
                      ? 'Back to Login'
                      : _registerMode
                      ? 'Already verified? Login'
                      : 'Need an account? Sign up',
                ),
              ),
              if (!_registerMode && !_forgotPasswordMode)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _forgotPasswordMode = true;
                            _message = '';
                            _devActionUrl = '';
                          });
                        },
                  child: const Text('Forgot password?'),
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
        _devActionUrl =
            emailVerification['devVerificationUrl']?.toString() ?? '';
        _registerMode = false;
      });
    });
  }

  Future<void> _requestPasswordReset() async {
    await _runAuthAction(() async {
      final response = await widget.apiClient.postJson(
        '/auth/forgot-password',
        {'email': _emailController.text.trim()},
      );
      final passwordReset = _asMap(response['passwordReset']);
      setState(() {
        _message =
            response['message']?.toString() ??
            'If the email exists, a reset link has been sent.';
        _devActionUrl = passwordReset['devResetUrl']?.toString() ?? '';
      });
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = '';
      _devActionUrl = '';
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

  bool _isPositiveMessage(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('success') ||
        normalized.contains('verify') ||
        normalized.contains('sent') ||
        normalized.contains('updated');
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.appIdentityKey,
    required this.sectionKeys,
    required this.logoutKey,
    required this.section,
    required this.user,
    required this.onLogout,
    required this.onSectionChanged,
  });

  final GlobalKey appIdentityKey;
  final Map<AppSection, GlobalKey> sectionKeys;
  final GlobalKey logoutKey;
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
            key: appIdentityKey,
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
                    key: sectionKeys[entry],
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
            key: logoutKey,
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
    super.key,
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
