import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../infrastructure/export/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());
