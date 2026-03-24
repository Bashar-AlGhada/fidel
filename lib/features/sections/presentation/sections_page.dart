import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_card.dart';
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
    final ref = this.ref;
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.info) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.info);
      });
    }

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
                    onPressed: () => setState(() => _query = ''),
                  ),
              ],
            ),
            SizedBox(height: tokens.space2),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1100
                      ? 3
                      : width >= 700
                      ? 2
                      : 1;

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: tokens.space2,
                      mainAxisSpacing: tokens.space2,
                      childAspectRatio: columns == 1 ? 3.2 : 2.6,
                    ),
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      final meta = ref.watch(
                        sectionMetadataStreamProvider(section.id),
                      );
                      final subtitle = meta.when(
                        data: (v) => 'availability.${v.availability.name}'.tr,
                        loading: () => 'availability.loading'.tr,
                        error: (err, st) => 'availability.unavailable'.tr,
                      );

                      return AppCard(
                        onTap: () => context.go('/info/${section.pathSegment}'),
                        child: Row(
                          children: [
                            Icon(
                              section.icon,
                              color: theme.colorScheme.primary,
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
                                  SizedBox(height: tokens.space1),
                                  Text(
                                    subtitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      );
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
