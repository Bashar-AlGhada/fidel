import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';
import 'app_states.dart';
import 'section_badges.dart';

/// A `(filterId, filterLabel)` pair.
typedef FilterOption = (String id, String label);

/// Reusable searchable + filterable list body for entity sections
/// (cameras, codecs, sensors, ...).
///
/// Renders a Material 3 [SearchBar], a horizontal row of
/// [SectionFilterChip]s from [filters], optional [summaryBadges], then the
/// items built by [itemBuilder]. Empty and no-results states are built in;
/// the caller distinguishes them by mutating its own query/filters before
/// passing [hasActiveQuery].
///
/// Default empty/no-results strings are neutral English fallbacks; pass
/// [emptyState]/[noResultsState] with localized `AppEmptyState`s for
/// production pages.
///
/// Must be given bounded height (e.g. directly under a Scaffold body).
class FilterableEntityList extends StatelessWidget {
  const FilterableEntityList({
    required this.searchHint,
    required this.itemCount,
    required this.itemBuilder,
    this.filters = const [],
    this.selectedFilters = const {},
    this.onToggleFilter,
    this.searchQuery = '',
    this.searchController,
    this.onSearchChanged,
    this.summaryBadges = const [],
    this.hasActiveQuery = false,
    this.emptyState,
    this.noResultsState,
    super.key,
  });

  final String searchHint;

  /// Available filters; ids must be stable strings (e.g. enum names).
  final List<FilterOption> filters;

  /// Currently selected filter ids.
  final Set<String> selectedFilters;

  /// Called with the toggled filter id.
  final void Function(String id)? onToggleFilter;

  /// Current search text (controlled).
  final String searchQuery;

  /// Optional external controller; when omitted the field is uncontrolled
  /// and [onSearchChanged] drives all updates.
  final TextEditingController? searchController;

  /// Search text changed callback. Omit for a display-only field.
  final ValueChanged<String>? onSearchChanged;

  /// Summary pills shown under the filter row (e.g. `SectionSummaryBadge`).
  final List<Widget> summaryBadges;

  /// Whether a search query or non-default filter is active — selects the
  /// no-results state over the empty state when [itemCount] is 0.
  final bool hasActiveQuery;

  /// Overrides the default empty state (shown when count == 0 and no
  /// active query).
  final Widget? emptyState;

  /// Overrides the default no-results state (active query but zero hits).
  final Widget? noResultsState;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchBar(
          hintText: searchHint,
          constraints: const BoxConstraints(minHeight: 48),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainer,
          ),
          leading: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          trailing: [
            if (onSearchChanged != null && searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => onSearchChanged!(''),
              ),
          ],
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          controller: searchController,
          onChanged: onSearchChanged,
        ),
        if (filters.isNotEmpty) ...[
          SizedBox(height: tokens.space2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final (id, label) in filters) ...[
                  SectionFilterChip(
                    selected: selectedFilters.contains(id),
                    label: label,
                    onTap:
                        onToggleFilter != null
                            ? () => onToggleFilter!(id)
                            : () {},
                  ),
                  SizedBox(width: tokens.space1),
                ],
              ],
            ),
          ),
        ],
        if (summaryBadges.isNotEmpty) ...[
          SizedBox(height: tokens.space2),
          Wrap(spacing: tokens.space2, runSpacing: tokens.space1, children: summaryBadges),
        ],
        SizedBox(height: tokens.space2),
        if (itemCount == 0)
          Expanded(
            child: hasActiveQuery
                ? (noResultsState ??
                      AppEmptyState(
                        title: 'No results',
                        message: 'Try a different search or filter.',
                        icon: Icons.search_off,
                      ))
                : (emptyState ??
                      AppEmptyState(title: 'Nothing here yet', icon: Icons.inbox_outlined)),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: itemCount,
              separatorBuilder: (_, _) => SizedBox(height: tokens.space2),
              itemBuilder: itemBuilder,
            ),
          ),
      ],
    );
  }
}
