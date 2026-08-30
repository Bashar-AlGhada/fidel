/// Compatibility shim: canonical implementations now live in `core/ui`.
///
/// Kept so existing feature imports (`widgets/section_cards.dart`) keep
/// resolving while pages migrate to direct `core/ui` imports.
library;

export '../../../../core/ui/section_badges.dart';
export '../../../../core/ui/spec_row.dart';
