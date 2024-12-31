import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_paging_controller/src/data_cursor.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

typedef FromMap<T> = T Function(Map<String, dynamic>);

/// Has the same interface as [FirestorePagingController], but accepts multiple queries
/// which mimics the OR or union operator. All the queries will feed into one
/// list, which is accessible through the getter.
/// It can be used with [PagedListView] for infinite scroll, or with the
/// [AppLoadMoreList] for user click to load infinite load.
///
/// Warning: Sorting is not supported. If you want that, use Algolia.
class FirestorePagingController<ItemType>
    extends PagingController<int, QueryDocumentSnapshot<ItemType>> {
  /// The base path to the collection in Firestore
  final String basePath;

  /// The Firestore instance to use. If not provided, it will use the default instance.
  final FirebaseFirestore firestore;

  final FromMap<ItemType>? fromMap;

  late final List<DataCursor<ItemType>> _cursors;
  final int pageSize;

  static _allItemsQuery<ItemType>() => (Query<ItemType> query) => query;

  /// Creates a [FirestorePagingController] that fetches items from Firestore and
  /// paginates them to be used with infinite_scroll_pagination views, like [PagedListView].
  ///
  /// Parameters:
  /// - [basePath] - The base path to the collection in Firestore
  /// - [firestore] - The Firestore instance to use. If not provided, it will use the default instance.
  /// - [queryBuilders] - A list of query builders. If you want to fetch all items, leave it null.
  FirestorePagingController({
    required this.basePath,
    FirebaseFirestore? firestore,
    List<Query<ItemType> Function(Query<ItemType> query)>? queryBuilders,
    this.fromMap,
    this.pageSize = 10,
  })  : assert(
          ItemType is Map<String, dynamic> || fromMap != null,
          'fromMap is required when ItemType is not Map<String, dynamic>',
        ),
        assert(
          queryBuilders?.isEmpty != true,
          'At least one queryBuilder is required. If you want to fetch all items, leave it null.',
        ),
        assert(pageSize > 0),
        firestore = firestore ?? FirebaseFirestore.instance,
        super(firstPageKey: 0) {
    queryBuilders ??= [_allItemsQuery<ItemType>()];

    _cursors = queryBuilders.map(
      (queryBuilder) {
        final query = queryBuilder(
          this.firestore.collection(basePath).withConverter<ItemType>(
                fromFirestore: (snapshot, _) =>
                    fromMap?.call(snapshot.data()!) ??
                    snapshot.data() as ItemType,
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

        return DataCursor(query.limit(pageSize));
      },
    ).toList();

    addPageRequestListener(_fetch);
  }

  Future<void> _fetch(int pageKey) async {
    try {
      final results = await _cursors.map((e) => e.fetchNextPage()).wait;

      final isLastPage = !results.any((result) => result.length == pageSize);

      final newItems = results
          .expand((e) => e)
          .toSet()
          .where((item) => value.itemList?.contains(item) != true)
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
