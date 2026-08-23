/// Compile-time environment flags shared across layers.
library;

const bool appIsTest = bool.fromEnvironment('FLUTTER_TEST');
