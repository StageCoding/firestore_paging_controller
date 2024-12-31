import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class DataCursor<T> {
  DataCursor(this._query);

  final Query<T> _query;

  var _isLoading = false;
  bool get isLoading => _isLoading;

  DocumentSnapshot? _lastVisible;

  var isEverythingLoaded = false;

  Future<List<QueryDocumentSnapshot<T>>> fetchNextPage() async {
    if (isLoading) {
      throw 'DataCursor is already fetching';
    }

    if (isEverythingLoaded) {
      return [];
    }

    _isLoading = true;

    final next = _lastVisible == null
        ? _query
        : _query.startAfterDocument(_lastVisible!);

    try {
      final response = await next.get();

      if (response.docs.isEmpty) {
        isEverythingLoaded = true;
        return [];
      }

      _lastVisible = response.docs.last;

      return response.docs;
    } finally {
      _isLoading = false;
    }
  }
}
