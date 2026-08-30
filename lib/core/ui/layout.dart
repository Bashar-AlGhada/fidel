/// Shared responsive-grid helpers.
library;

/// Width at which single-column phone layouts gain a second column.
/// Aligned with the nav shell's medium tier.
const double kCompactBreakpoint = 700.0;

/// Width at which grids expand to three columns (extended tier).
///
/// Note: `app_nav_shell.dart` still switches its rail layout at 1000; new
/// code should prefer [kExtendedBreakpoint] for content density decisions.
const double kExtendedBreakpoint = 1100.0;

/// Column count for card grids at the given viewport width.
int responsiveGridColumns(double width) {
  if (width >= kExtendedBreakpoint) return 3;
  if (width >= kCompactBreakpoint) return 2;
  return 1;
}

/// Aspect ratio matching [responsiveGridColumns] so tiles stay readable
/// on single-column phone layouts.
double responsiveGridChildAspectRatio(int columns) => columns == 1 ? 3.2 : 2.4;
