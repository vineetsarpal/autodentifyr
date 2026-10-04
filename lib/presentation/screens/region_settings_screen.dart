import 'package:flutter/material.dart';

import 'package:autodentifyr/core/localization/region_catalog.dart';
import 'package:autodentifyr/presentation/controllers/region_preference_controller.dart';

/// The caller owns the controller, so selections also update the home screen.
class RegionSettingsScreen extends StatefulWidget {
  const RegionSettingsScreen({super.key, required this.controller});

  final RegionPreferenceController controller;

  @override
  State<RegionSettingsScreen> createState() => _RegionSettingsScreenState();
}

class _RegionSettingsScreenState extends State<RegionSettingsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final region = controller.region;
        final countries = RegionCatalog.countries.where(
          (country) =>
              country.name.toLowerCase().contains(_query) ||
              country.countryCode.toLowerCase().contains(_query) ||
              country.currencyCode.toLowerCase().contains(_query),
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Region & currency')),
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region == null
                              ? 'Choose your country'
                              : '${region.name} · ${region.currencyCode}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.source == RegionPreferenceSource.manual
                              ? 'Your selection is saved on this device.'
                              : region == null
                              ? 'Your device region is unavailable or unsupported. Select a country below.'
                              : 'Suggested from your device region. Confirm by selecting your country below.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose the country where repair pricing should apply. '
                          'Local currency pricing is coming later. '
                          'Your location is not tracked.',
                        ),
                        TextButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () => controller.selectCountry(null),
                          icon: const Icon(Icons.settings_backup_restore),
                          label: const Text('Use device region'),
                        ),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search country or currency',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() {
                            _query = value.trim().toLowerCase();
                          }),
                        ),
                        if (controller.error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            controller.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton(
                            onPressed: controller.isBusy
                                ? null
                                : controller.load,
                            child: const Text('Retry loading'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (controller.isBusy)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                if (countries.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No supported countries match your search.'),
                    ),
                  )
                else
                  SliverList.list(
                    children: [
                      for (final country in countries)
                        ListTile(
                          title: Text(country.name),
                          subtitle: Text(country.currencyCode),
                          selected: region == country,
                          trailing: region == country
                              ? const Icon(Icons.check)
                              : null,
                          enabled: !controller.isBusy,
                          onTap: () =>
                              controller.selectCountry(country.countryCode),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
