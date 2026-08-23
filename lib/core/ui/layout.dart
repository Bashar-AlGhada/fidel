/// Shared responsive-grid helpers.
library;

/// Column count for card grids at the given viewport width.
int responsiveGridColumns(double width) {
  if (width >= 1100) return 3;
  if (width >= 700) return 2;
  return 1;
}

/// Aspect ratio matching [responsiveGridColumns] so tiles stay readable
/// on single-column phone layouts.
double responsiveGridChildAspectRatio(int columns) => columns == 1 ? 3.2 : 2.4;
