enum InfoItemValueKind { text, redacted, hidden }

class InfoItemValue {
  const InfoItemValue._(this.kind, this.text);

  final InfoItemValueKind kind;
  final String? text;

  const InfoItemValue.text(String text) : this._(InfoItemValueKind.text, text);
  const InfoItemValue.redacted() : this._(InfoItemValueKind.redacted, null);
  const InfoItemValue.hidden() : this._(InfoItemValueKind.hidden, null);
}
