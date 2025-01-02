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

final controller = FirestorePagingController.withoutType(
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
PagedListView(
  pagingController: controller,
  builderDelegate: PagedChildBuilderDelegate<QueryDocumentSnapshot<Map<String, dynamic>>>(
    itemBuilder: (context, snapshot, index) => Post(snapshot.data()),
  ),
);
```

If you want to use the type-safe version of the controller, you can do the following:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_paging_controller/firestore_paging_controller.dart';

final controller = FirestorePagingController<PostModel>.converted(
  basePath: 'posts',
  queryBuilders: [
    (query) => query.where('creatorId', isEqualTo: userId),
    (query) => query.where('taggedUserId', isEqualTo: userId),
  ],
  orderBy: 'createdAt',
  orderByDescending: true,
  pageSize: 10,
  fromMap: (data) => PostModel.fromMap(data),
);
```

Then it can be used like this:

```dart
PagedListView<int, QueryDocumentSnapshot<T>>(
  pagingController: controller,
  builderDelegate: PagedChildBuilderDelegate<QueryDocumentSnapshot<T>>(
    itemBuilder: (context, snapshot, index) => Post(snapshot.data()),
  ),
);
```

## Reminders:
- The queries you pass to the controller should not have any limit or orderBy applied to them.
- You may need to create an index in Firestore for the queries you are using in the controller. Look at the logs for the error message and create the index accordingly.
