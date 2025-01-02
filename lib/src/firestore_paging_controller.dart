import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_paging_controller/src/data_cursor.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

typedef StringMap = Map<String, dynamic>;
typedef FromMap<T> = T Function(StringMap);

/// {@template firestore_paging_controller}
/// Creates a [FirestorePagingController] that fetches items from Firestore and
/// paginates them to be used with infinite_scroll_pagination views, like [PagedListView].
///
/// Parameters:
/// - `basePath` - The base path to the collection in Firestore
/// - `firestore` - The Firestore instance to use. If not provided, it will use the default instance.
/// - `queryBuilders` - A list of query builders. If you want to fetch all items, leave it null.
/// - `fromMap` - A function to convert a Firestore document to the desired item type.
/// - `pageSize` - The number of items to fetch per page. Default is 10. When there are multiple
/// queryBuilders, the pageSize is the total number of items to fetch per query. If
/// more than one query is provided, there is no guarantee that each query will have the same number of items to show at
/// the same time. Every batch will have from 0 to pageSize * queryBuilders.length items
/// - `orderBy` - The field to order the items by. It can't be a documentId because
/// the cursor is based on the last document fetched, and we use startAfterDocument
/// to fetch the next page.
/// - `orderByDescending` - Whether to order the items in descending order. Default is false.
/// {@endtemplate}
class FirestorePagingController<ItemType>
    extends PagingController<int, QueryDocumentSnapshot<ItemType>> {
  /// The base path to the collection in Firestore
  final String basePath;

  /// The Firestore instance to use. If not provided, it will use the default instance.
  final FirebaseFirestore firestore;

  /// A function to convert a Firestore document to the desired item type.
  final FromMap<ItemType> fromMap;

  late final List<DataCursor<ItemType>> _cursors;

  /// The number of items to fetch per page. Default is 10. When there are multiple
  /// queryBuilders, the pageSize is the total number of items to fetch per query. If
  /// more than one query is provided, there is no guarantee that each query will have the same number of items to show at
  /// the same time. Every batch will have from 0 to pageSize * queryBuilders.length items
  final int pageSize;

  /// Items by queries that are waiting to be displayed in the next pages because other
  /// cursors may still have items before them in ordering sequence.
  final List<List<QueryDocumentSnapshot<ItemType>>> _queryWaitingResults;

  /// The field to order the items by. It can't be a documentId because
  /// the cursor is based on the last document fetched, and we use startAfterDocument
  /// to fetch the next page.
  final String? orderBy;

  /// Whether to order the items in descending order. Default is false.
  final bool orderByDescending;

  /// {@macro firestore_paging_controller}
  static FirestorePagingController<StringMap> withoutType({
    required String basePath,
    FirebaseFirestore? firestore,
    List<Query<StringMap> Function(CollectionReference<StringMap> query)>?
        queryBuilders,
    int pageSize = 10,
    String? orderBy,
    bool orderByDescending = false,
  }) {
    return FirestorePagingController<StringMap>.converted(
      basePath: basePath,
      firestore: firestore,
      queryBuilders: queryBuilders,
      fromMap: (data) => data,
      pageSize: pageSize,
      orderBy: orderBy,
      orderByDescending: orderByDescending,
    );
  }

  /// {@macro firestore_paging_controller}
  FirestorePagingController.converted({
    required this.basePath,
    FirebaseFirestore? firestore,
    List<Query<ItemType> Function(CollectionReference<ItemType> query)>?
        queryBuilders,
    required this.fromMap,
    this.pageSize = 10,
    this.orderBy,
    this.orderByDescending = false,
  })  : assert(
          queryBuilders?.isEmpty != true,
          'At least one queryBuilder is required. If you want to fetch all items, leave it null.',
        ),
        assert(pageSize > 0),
        firestore = firestore ?? FirebaseFirestore.instance,
        _queryWaitingResults =
            List.generate(queryBuilders?.length ?? 1, (_) => []),
        super(firstPageKey: 0) {
    // If user didn't provide any queryBuilders, we will fetch all items
    queryBuilders ??= [(query) => query];

    _cursors = queryBuilders.map(
      (queryBuilder) {
        var query = queryBuilder(
          this.firestore.collection(basePath).withConverter<ItemType>(
                fromFirestore: (snapshot, _) => fromMap.call(snapshot.data()!),
                toFirestore: (item, _) => throw Exception(
                    'You cannot write to Firestore in FirestorePagingController'),
              ),
        );

        assert(
          List.from(query.parameters['orderBy'] ?? []).isEmpty,
          'Ordering is done through orderBy in FirestoreUnionPagingController',
        );

        assert(
          List.from(query.parameters['limit'] ?? []).isEmpty,
          'Limiting is done through pageSize in FirestoreUnionPagingController',
        );

        if (orderBy != null) {
          query = query.orderBy(orderBy!, descending: orderByDescending);
        }

        return DataCursor(query);
      },
    ).toList();

    addPageRequestListener(_fetch);
  }

  Future<void> _fetch(int pageKey) async {
    try {
      var results = await _cursors
          .asMap()
          .map((i, e) => MapEntry(
              i, e.fetchNextPage(pageSize - _queryWaitingResults[i].length)))
          .values
          .wait;

      if (orderBy != null) {
        // Add items that are waiting to be displayed in the next pages
        results = results
            .asMap()
            .map((i, e) => MapEntry(i, [
                  ..._queryWaitingResults[i],
                  ...e,
                ]))
            .values
            .toList();

        for (var e in _queryWaitingResults) {
          e.clear();
        }

        final notExhaustedCursors = results.where((e) => e.length == pageSize);

        if (notExhaustedCursors.isNotEmpty) {
          // Value of the field we are ordering by in the last document of each cursor
          final pivotFieldValue = notExhaustedCursors
              // Get the last document of each cursor, as it is already ordered by firebase
              .map((e) => e.last)
              .map((e) => e.get(orderBy!))
              .reduce((value, element) {
            if (orderByDescending) {
              return value.compareTo(element) > 0 ? value : element;
            } else {
              return value.compareTo(element) < 0 ? value : element;
            }
          });

          for (var i = 0; i < results.length; i++) {
            final itemsToWait = results[i].where((e) {
              final value = e.get(orderBy!);
              return orderByDescending
                  ? value.compareTo(pivotFieldValue) < 0
                  : value.compareTo(pivotFieldValue) > 0;
            }).toList();

            _queryWaitingResults[i].addAll(itemsToWait);
            results[i].removeWhere((e) => itemsToWait.contains(e));
          }
        }
      }

      final isLastPage = results.every((result) => result.length < pageSize);

      final newItems = results
          .expand((e) => e)
          // Remove local duplicates, orderin not preserved but we need to
          // order anyways after meshing all results
          .toSet()
          // Remove duplicates from already added items, because other queries
          // may have the same items
          .where((e) => value.itemList?.every((i) => i.id != e.id) != false)
          .toList();

      if (orderBy != null) {
        if (orderByDescending) {
          newItems.sort((a, b) => b.get(orderBy!).compareTo(a.get(orderBy!)));
        } else {
          newItems.sort((a, b) => a.get(orderBy!).compareTo(b.get(orderBy!)));
        }
      }

      if (isLastPage) {
        appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        appendPage(newItems, nextPageKey);
      }
    } catch (e) {
      error = e;
    }
  }
}
