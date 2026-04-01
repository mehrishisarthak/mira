class Search {
  final String url;

  Search({required this.url});

  Search copyWith({
    String? url,
  }) {
    return Search(
      url: url ?? this.url,
    );
  }
}
