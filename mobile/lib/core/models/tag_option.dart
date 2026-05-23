class TagOption<TValue extends Object> {
  const TagOption({
    required this.value,
    required this.label,
    this.aliases = const <String>[],
  });

  final TValue value;
  final String label;
  final List<String> aliases;

  TValue get backendValue => value;

  String get displayLabel => label;
}
