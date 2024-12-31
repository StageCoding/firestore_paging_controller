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
/// - [basePath] - The base path to the collection in Firestore
/// - [firestore] - The Firestore instance to use. If not provided, it will use the default instance.
/// - [queryBuilders] - A list of query builders. If you want to fetch all items, leave it null.
/// - [fromMap] - A function to convert a Firestore document to the desired item type.
/// - [pageSize] - The number of items to fetch per page. Default is 10.
/// - [orderBy] - The field to order the items by. It can't be a documentId because
/// the cursor is based on the last document fetched, and we use startAfterDocument
/// to fetch the next page.
/// - [orderByDescending] - Whether to order the items in descending order. Default is false.
/// {@endtemplate}
class FirestorePagingController<ItemType>
    extends PagingController<int, QueryDocumentSnapshot<ItemType>> {
  /// The base path to the collection in Firestore
  final String basePath;

  /// The Firestore instance to use. If not provided, it will use the default instance.
  final FirebaseFirestore firestore;

  final FromMap<ItemType> fromMap;

  late final List<DataCursor<ItemType>> _cursors;
  final int pageSize;

  /// Items by queries that are waiting to be displayed in the next pages because other
  /// cursors may still have items before them in ordering sequence.
  final List<List<QueryDocumentSnapshot<ItemType>>> _queryWaitingResults;

  final String? orderBy;
  final bool orderByDescending;

  /// {@macro firestore_paging_controller}
  static FirestorePagingController<StringMap> withoutType({
    required String basePath,
    FirebaseFirestore? firestore,
    List<Query<StringMap> Function(Query<StringMap> query)>? queryBuilders,
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
        _queryWaitingResults = List.filled(queryBuilders?.length ?? 1, []),
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
          List.from(query.parameters['orderBy']).isEmpty,
          'Sorting is not supported in FirestoreUnionPagingController',
        );

        assert(
          List.from(query.parameters['limit']).isEmpty,
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
      final newResults = await _cursors
          .asMap()
          .map((i, e) => MapEntry(
              i, e.fetchNextPage(pageSize - _queryWaitingResults[i].length)))
          .values
          .wait;

      final results = newResults
          .asMap()
          .map((i, e) => MapEntry(i, [
                ..._queryWaitingResults[i],
                ...e,
              ]))
          .values
          .toList();

      if (orderBy != null) {
        // Value of the field we are ordering by in the last document of each cursor
        final pivotFieldValue = results
            .map((e) => e.lastOrNull)
            .whereType<QueryDocumentSnapshot<ItemType>>()
            .map((e) => e.get(orderBy!));

        for (var i = 0; i < results.length; i++) {
          final itemsToWait = results[i].where((e) {
            final value = e.get(orderBy!);
            return orderByDescending
                ? value.compareTo(pivotFieldValue.elementAt(i)) >= 0
                : value.compareTo(pivotFieldValue.elementAt(i)) <= 0;
          }).toList();

          _queryWaitingResults[i].addAll(itemsToWait);
          results[i].removeWhere((e) => itemsToWait.contains(e));
        }
      }

      final isLastPage = !results.any((result) => result.length == pageSize);

      final newItems = results
          .expand((e) => e)
          .toSet()
          .where((item) => value.itemList?.any((e) => e.id == item.id) != true)
          .toList();

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
