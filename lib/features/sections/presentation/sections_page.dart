import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/layout.dart';
import '../../../domain/entities/info/info_availability.dart';
import '../sections_registry.dart';

class SectionsPage extends ConsumerStatefulWidget {
  const SectionsPage({super.key});

  @override
  ConsumerState<SectionsPage> createState() => _SectionsPageState();
}

class _SectionsPageState extends ConsumerState<SectionsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    final query = _query.trim().toLowerCase();
    final sections = query.isEmpty
        ? sectionDefinitions
        : sectionDefinitions
              .where((s) {
                final title = s.titleKey.tr.toLowerCase();
                return title.contains(query) || s.id.contains(query);
              })
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text('nav.info'.tr)),
      body: Padding(
        padding: EdgeInsets.all(tokens.space2),
        child: Column(
          children: [
            SearchBar(
              hintText: 'search.hintSections'.tr,
              onChanged: (v) => setState(() => _query = v),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'action.clear'.tr,
                    onPressed: () => setState(() => _query = ''),
                  ),
              ],
            ),
            SizedBox(height: tokens.space2),
            Expanded(
              child: sections.isEmpty
                  ? AppEmptyState(
                      title: 'search.noResults'.tr,
                      icon: Icons.search_off_outlined,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = responsiveGridColumns(
                          constraints.maxWidth,
                        );

                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: tokens.space2,
                                mainAxisSpacing: tokens.space2,
                                childAspectRatio:
                                    responsiveGridChildAspectRatio(columns),
                              ),
                          itemCount: sections.length,
                          itemBuilder: (context, index) {
                            final section = sections[index];
                            return _SectionTile(section: section);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});

  final SectionDefinition section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // Scoped so one section's update does not rebuild the whole grid.
    return Consumer(
      builder: (context, ref, _) {
        final meta = ref.watch(
          sectionMetadataStreamProvider(section.id),
        );
        final availability = meta.asData?.value.availability;
        final available =
            availability == null || availability == InfoAvailability.available;
        final caption = meta.when(
          skipLoadingOnReload: true,
          data: (v) => 'availability.${v.availability.name}'.tr,
          loading: () => 'availability.loading'.tr,
          error: (err, st) => 'availability.unavailable'.tr,
        );

        return GlassCard(
          onTap: () => context.go('/info/${section.pathSegment}'),
          padding: EdgeInsets.all(tokens.space2),
          highlightBorder: available && meta.asData != null,
          child: Row(
            children: [
              Container(
                width: tokens.space4 + 8,
                height: tokens.space4 + 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: Icon(
                  section.icon,
                  size: 22,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      section.titleKey.tr,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.space1 / 2),
                    Text(
                      caption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.space1),
              CircleAvatar(
                radius: 4,
                backgroundColor: available
                    ? tokens.successColor
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              SizedBox(width: tokens.space1),
              const Icon(Icons.chevron_right),
            ],
          ),
        );
      },
    );
  }
}
