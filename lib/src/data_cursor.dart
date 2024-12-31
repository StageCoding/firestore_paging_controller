import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class DataCursor<T> {
  DataCursor(this._query);

  final Query<T> _query;

  var _isLoading = false;
  bool get isLoading => _isLoading;

  DocumentSnapshot? _lastVisible;

  Future<List<QueryDocumentSnapshot<T>>> fetchNextPage(int items) async {
    if (items <= 0) return [];

    if (isLoading) {
      throw 'DataCursor is already fetching';
    }

    _isLoading = true;

    var query = _query.limit(items);

    if (_lastVisible != null) query = query.startAfterDocument(_lastVisible!);

    try {
      final response = await query.get();

      if (response.docs.isEmpty) return [];

      _lastVisible = response.docs.last;

      return response.docs;
    } finally {
      _isLoading = false;
    }
  }
}
