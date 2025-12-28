

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// ignore: camel_case_types
class SearchNotifier extends StateNotifier <Search> {
  SearchNotifier(super.state);

  void updateUrl (String urlProvided){
    state = state.copyWith(url: urlProvided);
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, Search>((ref) {
  return SearchNotifier(Search(url: ''));
});