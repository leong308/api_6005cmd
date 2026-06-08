import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/core/api/api_config.dart';
import 'package:api_6005cmd/features/api_demo/data/api_demo_data_source.dart';
import 'package:api_6005cmd/features/api_demo/model/api_endpoint_model.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:flutter/material.dart';

class ApiDemoPage extends StatelessWidget {
  const ApiDemoPage({
    super.key,
    required this.dataSource,
  });

  final ApiDemoDataSource dataSource;

  @override
  Widget build(BuildContext context) {
    final endpoints = dataSource.endpoints();
    final totalEndpoints = endpoints.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'API / Testing Demo',
          trailing: Text(
            '$totalEndpoints endpoints',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppPalette.inkA(0.66)),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              const _EnvironmentCard(),
              const SizedBox(height: 12),
              _EndpointGroupTile(
                title: 'System',
                subtitle: 'Health and diagnostics',
                color: AppPalette.inkA(0.05),
                endpoints: endpoints
                    .where((e) => e.group == EndpointGroup.system)
                    .toList(),
              ),
              const SizedBox(height: 12),
              _EndpointGroupTile(
                title: 'Trip CRUD',
                subtitle: 'Self-developed API',
                color: AppPalette.blueA(0.07),
                endpoints: endpoints
                    .where((e) => e.group == EndpointGroup.tripCrud)
                    .toList(),
              ),
              const SizedBox(height: 12),
              _EndpointGroupTile(
                title: 'External Data',
                subtitle: 'Third-party module endpoints',
                color: AppPalette.mintA(0.07),
                endpoints: endpoints
                    .where((e) => e.group == EndpointGroup.externalData)
                    .toList(),
              ),
              const SizedBox(height: 12),
              _EndpointGroupTile(
                title: 'Combined Output',
                subtitle: 'Final connected endpoint',
                color: AppPalette.coralA(0.07),
                endpoints: endpoints
                    .where((e) => e.group == EndpointGroup.combinedOutput)
                    .toList(),
              ),
              const SizedBox(height: 12),
              _EndpointGroupTile(
                title: 'Optional Authentication',
                subtitle: 'Auth, verification, and user profile',
                color: AppPalette.inkA(0.06),
                endpoints: endpoints
                    .where((e) => e.group == EndpointGroup.optionalAuth)
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard();

  @override
  Widget build(BuildContext context) {
    return MacPanel(
      color: AppPalette.blueA(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API Integration Ready',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _line('Self API Base URL', ApiConfig.selfApiBaseUrl),
          _line('External Proxy Base URL', ApiConfig.externalProxyBaseUrl),
          _line('Timeout', '${ApiConfig.requestTimeout.inSeconds}s'),
          const SizedBox(height: 8),
          Text(
            'Refresh External Data sends refresh=true, bypasses external caches, '
            'and replaces Mongo cache when fresh data is returned. Keep API keys '
            'in environment variables.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.inkA(0.64),
                ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText(
        '$label: $value',
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
      ),
    );
  }
}

class _EndpointGroupTile extends StatefulWidget {
  const _EndpointGroupTile({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.endpoints,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<ApiEndpointModel> endpoints;

  @override
  State<_EndpointGroupTile> createState() => _EndpointGroupTileState();
}

class _EndpointGroupTileState extends State<_EndpointGroupTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return MacPanel(
      color: widget.color,
      child: ExpansionTile(
        initiallyExpanded: true,
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        iconColor: AppPalette.ink,
        collapsedIconColor: AppPalette.inkA(0.7),
        title: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${widget.subtitle} • ${widget.endpoints.length} endpoint(s)',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppPalette.inkA(0.62)),
        ),
        trailing: AnimatedRotation(
          turns: _expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          child: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        children: [
          for (final endpoint in widget.endpoints) ...[
            _EndpointRow(endpoint: endpoint),
            if (endpoint != widget.endpoints.last) const Divider(height: 16),
          ],
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.endpoint});

  final ApiEndpointModel endpoint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MethodBadge(method: endpoint.method),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                endpoint.path,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                endpoint.description + (endpoint.optional ? ' (Optional)' : ''),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final style = switch (method) {
      'GET' => const _BadgeStyle(bg: AppPalette.blue, text: AppPalette.white),
      'POST' => const _BadgeStyle(bg: AppPalette.mint, text: AppPalette.white),
      'PUT' => const _BadgeStyle(bg: AppPalette.coral, text: AppPalette.white),
      'DELETE' => const _BadgeStyle(bg: AppPalette.ink, text: AppPalette.white),
      _ => const _BadgeStyle(bg: AppPalette.ink, text: AppPalette.white),
    };

    return Container(
      width: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: style.text,
        ),
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({required this.bg, required this.text});

  final Color bg;
  final Color text;
}
