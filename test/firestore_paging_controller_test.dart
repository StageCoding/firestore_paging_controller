import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_paging_controller/src/firestore_paging_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firestore_paging_controller/firestore_paging_controller.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<StringMap>>(),
  MockSpec<Query<StringMap>>(),
  MockSpec<QuerySnapshot<StringMap>>(),
  MockSpec<QueryDocumentSnapshot<StringMap>>(),
  MockSpec<CollectionReference<TestModel>>(
      as: #MockCollectionReferenceTestModel),
  MockSpec<Query<TestModel>>(as: #MockQueryTestModel),
  MockSpec<QuerySnapshot<TestModel>>(as: #MockQuerySnapshotTestModel),
  MockSpec<QueryDocumentSnapshot<TestModel>>(
      as: #MockQueryDocumentSnapshotTestModel),
])
import 'firestore_paging_controller_test.mocks.dart';
import 'test_model.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollectionReference;
  late MockCollectionReference convertedMockCollectionReference;

  late FromFirestore<StringMap> fromFirestore;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();

    mockCollectionReference = MockCollectionReference();
    convertedMockCollectionReference = MockCollectionReference();

    when(mockCollectionReference.withConverter<StringMap>(
      fromFirestore: anyNamed('fromFirestore'),
      toFirestore: anyNamed('toFirestore'),
    )).thenAnswer((invocation) {
      fromFirestore =
          invocation.namedArguments[#fromFirestore] as FromFirestore<StringMap>;

      return convertedMockCollectionReference;
    });

    when(convertedMockCollectionReference.parameters).thenReturn({
      'orderBy': [],
      'limit': [],
    });

    when(mockFirestore.collection('users')).thenReturn(mockCollectionReference);
  });

  test('FirestorePagingController withoutType constructor', () {
    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
    );

    expect(controller.basePath, 'users');
    expect(controller.firestore, mockFirestore);
    expect(controller.pageSize, 10);
  });

  test('fetchPage with limit 15 and empty response', () async {
    final mockQuery = MockQuery();
    final mockQuerySnapshot = MockQuerySnapshot();

    when(convertedMockCollectionReference.limit(15)).thenReturn(mockQuery);
    when(mockQuery.get())
        .thenAnswer((_) async => Future.value(mockQuerySnapshot));

    when(mockQuerySnapshot.docs).thenReturn([]);

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      pageSize: 15,
    );

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, isEmpty);
    expect(controller.value.nextPageKey, isNull);
  });

  test('fetchPage with limit 15 and non-empty response', () async {
    final mockQuery = MockQuery();
    final mockQuerySnapshot = MockQuerySnapshot();

    when(convertedMockCollectionReference.limit(15)).thenReturn(mockQuery);
    when(mockQuery.get())
        .thenAnswer((_) async => Future.value(mockQuerySnapshot));

    final list = [
      {
        'name': 'Alice',
        'age': 30,
      },
      {
        'name': 'Bob',
        'age': 25,
      },
    ].map((data) {
      final mockDocumentSnapshot = MockQueryDocumentSnapshot();
      when(mockDocumentSnapshot.data()).thenReturn(data);
      return mockDocumentSnapshot;
    }).toList();

    when(mockQuerySnapshot.docs).thenReturn(list);

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      pageSize: 15,
    );

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, list);
    expect(controller.value.nextPageKey, isNull);

    final mockQueryDocumentSnapshot = MockQueryDocumentSnapshot();
    final data = {
      'name': 'Alice',
      'age': 30,
    };

    when(mockQueryDocumentSnapshot.data()).thenReturn(data);

    expect(fromFirestore(mockQueryDocumentSnapshot, null), data);
  });

  test('fetchPage with limit 15 and error response', () async {
    final mockQuery = MockQuery();

    when(convertedMockCollectionReference.limit(15)).thenReturn(mockQuery);
    when(mockQuery.get()).thenThrow(Exception('Error'));

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      pageSize: 15,
    );

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNotNull);
    expect(controller.itemList, isNull);
  });

  test('fetchPage with 2 pages', () async {
    final mockQuery = MockQuery();
    final mockQuerySnapshot = MockQuerySnapshot();

    when(convertedMockCollectionReference.limit(1)).thenReturn(mockQuery);
    when(mockQuery.get())
        .thenAnswer((_) async => Future.value(mockQuerySnapshot));

    when(mockQuery.startAfterDocument(any)).thenReturn(mockQuery);

    final mockDocumentSnapshot1 = MockQueryDocumentSnapshot();
    when(mockDocumentSnapshot1.id).thenReturn('1');
    when(mockDocumentSnapshot1.data()).thenReturn(
      {
        'name': 'Alice',
        'age': 30,
      },
    );

    when(mockQuerySnapshot.docs).thenReturn([mockDocumentSnapshot1]);

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      pageSize: 1,
    );

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, [mockDocumentSnapshot1]);
    expect(controller.value.nextPageKey, 1);

    final mockDocumentSnapshot2 = MockQueryDocumentSnapshot();
    when(mockDocumentSnapshot2.id).thenReturn('2');
    when(mockDocumentSnapshot2.data()).thenReturn(
      {
        'name': 'Alice',
        'age': 30,
      },
    );

    when(mockQuerySnapshot.docs).thenReturn([mockDocumentSnapshot2]);

    controller.notifyPageRequestListeners(controller.value.nextPageKey!);

    await Future.delayed(const Duration(milliseconds: 20));

    expect(controller.error, isNull);
    expect(controller.itemList, [mockDocumentSnapshot1, mockDocumentSnapshot2]);
    expect(controller.value.nextPageKey, 2);

    when(mockQuerySnapshot.docs).thenReturn([]);

    controller.notifyPageRequestListeners(controller.value.nextPageKey!);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, [mockDocumentSnapshot1, mockDocumentSnapshot2]);
    expect(controller.value.nextPageKey, isNull);
  });

  test('fetchPage with converted constructor', () async {
    final convertedMockCollectionReference = MockCollectionReferenceTestModel();

    late FromFirestore<TestModel> fromFirestore;
    late ToFirestore<TestModel> toFirestore;

    when(mockCollectionReference.withConverter<TestModel>(
      fromFirestore: anyNamed('fromFirestore'),
      toFirestore: anyNamed('toFirestore'),
    )).thenAnswer((invocation) {
      fromFirestore =
          invocation.namedArguments[#fromFirestore] as FromFirestore<TestModel>;
      toFirestore =
          invocation.namedArguments[#toFirestore] as ToFirestore<TestModel>;

      return convertedMockCollectionReference;
    });

    when(convertedMockCollectionReference.parameters).thenReturn({
      'orderBy': [],
      'limit': [],
    });

    final mockQuery = MockQueryTestModel();
    final mockQuerySnapshot = MockQuerySnapshotTestModel();

    when(convertedMockCollectionReference.limit(10)).thenReturn(mockQuery);
    when(mockQuery.get())
        .thenAnswer((_) async => Future.value(mockQuerySnapshot));

    final list = [
      TestModel(
        name: 'Alice',
        age: 30,
      ),
      TestModel(
        name: 'Bob',
        age: 25,
      ),
    ].map((data) {
      final mockDocumentSnapshot = MockQueryDocumentSnapshotTestModel();
      when(mockDocumentSnapshot.data()).thenReturn(data);
      return mockDocumentSnapshot;
    }).toList();

    when(mockQuerySnapshot.docs).thenReturn(list);

    final controller = FirestorePagingController<TestModel>.converted(
      basePath: 'users',
      firestore: mockFirestore,
      fromMap: (data) => TestModel.fromMap(data),
    );

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, list);
    expect(controller.value.nextPageKey, isNull);

    final mockDocumentSnapshot = MockQueryDocumentSnapshot();
    when(mockDocumentSnapshot.data()).thenReturn(
      {
        'name': 'Alice',
        'age': 30,
      },
    );

    expect(
      fromFirestore(mockDocumentSnapshot, null),
      TestModel(name: 'Alice', age: 30),
    );

    expect(
      () => toFirestore(TestModel(name: 'Alice', age: 30), null),
      throwsA(isA<Exception>()),
    );
  });

  test('orderBy', () async {
    final mockQuery = MockQuery();
    final mockQuerySnapshot = MockQuerySnapshot();

    when(mockQuery.get())
        .thenAnswer((_) async => Future.value(mockQuerySnapshot));
    when(convertedMockCollectionReference.orderBy('age',
            descending: anyNamed('descending')))
        .thenReturn(mockQuery);
    when(mockQuery.limit(10)).thenReturn(mockQuery);

    final list = List.generate(100, (i) => {'age': i}).map((data) {
      final mockDocumentSnapshot = MockQueryDocumentSnapshot();
      when(mockDocumentSnapshot.get('age')).thenReturn(data['age']);
      when(mockDocumentSnapshot.data()).thenReturn(data);
      return mockDocumentSnapshot;
    }).toList();

    when(mockQuerySnapshot.docs).thenReturn(list.sublist(0, 10));

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      orderBy: 'age',
    );

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, list.sublist(0, 10));
    expect(controller.value.nextPageKey, 1);
  });
}
