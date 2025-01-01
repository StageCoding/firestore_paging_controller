# Firestore Paging Controller

This is a simple Firestore Paging Controller package build on top of the [infinite_scroll_pagination](https://pub.dev/packages/infinite_scroll_pagination) package. It provides a simple way to paginate through Firestore collections.

Additionally, it provides a simple way to merge multiple queries into a single stream, which ultimately allows you to have an OR query. On top of that, it also allows ordering the results of the merged queries, which is not possible with Firestore. Internally, it uses the buffer to make sure it doesn't show the items in the wrong order.

## Getting Started

To use this package, you need to add the following dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  firestore_paging_controller: any
```

## Usage

To use this package, you need to create a `FirestorePagingController` and (optionally) pass it the queries you want to paginate through. Here is an example:

```dart
import 'package:firestore_paging_controller/firestore_paging_controller.dart';

final controller = FirestorePagingController(
  basePath: 'posts',
  queryBuilders: [
    (query) => query.where('creatorId', isEqualTo: userId),
    (query) => query.where('taggedUserId', isEqualTo: userId),
  ],
  orderBy: 'createdAt',
  orderByDescending: true,
  pageSize: 10,
);
```

This will create a controller that will paginate through the items that have the `creatorId` or `taggedUserId` equal to the `userId`. The controller will fetch 10 items per page for each query.

After creating the controller, you can use it in a widget from the [`infinite_scroll_pagination`](https://pub.dev/packages/infinite_scroll_pagination) package. Here is an example:

```dart
PagedListView<int, T>(
  pagingController: controller,
  builderDelegate: CustomPagedChildBuilderDelegate<T>(
    itemBuilder: (context, item, index) => Post(item),
  ),
);
```
