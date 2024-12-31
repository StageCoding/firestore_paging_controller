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

  /// {@macro firestore_paging_controller}
  static FirestorePagingController<StringMap> withoutType({
    required String basePath,
    FirebaseFirestore? firestore,
    List<Query<StringMap> Function(Query<StringMap> query)>? queryBuilders,
    int pageSize = 10,
  }) {
    return FirestorePagingController<StringMap>.converted(
      basePath: basePath,
      firestore: firestore,
      queryBuilders: queryBuilders,
      fromMap: (data) => data,
      pageSize: pageSize,
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
  })  : assert(
          queryBuilders?.isEmpty != true,
          'At least one queryBuilder is required. If you want to fetch all items, leave it null.',
        ),
        assert(pageSize > 0),
        firestore = firestore ?? FirebaseFirestore.instance,
        super(firstPageKey: 0) {
    // If user didn't provide any queryBuilders, we will fetch all items
    queryBuilders ??= [(query) => query];

    _cursors = queryBuilders.map(
      (queryBuilder) {
        final query = queryBuilder(
          this.firestore.collection(basePath).withConverter<ItemType>(
                fromFirestore: (snapshot, _) =>
                    fromMap.call(snapshot.data()!) ??
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
