class MemoryEntity {
  const MemoryEntity({required this.availBytes, required this.totalBytes});

  final int availBytes;
  final int totalBytes;

  int get usedBytes => (totalBytes - availBytes).clamp(0, totalBytes);

  double get usedRatio => totalBytes == 0 ? 0 : usedBytes / totalBytes;
}
