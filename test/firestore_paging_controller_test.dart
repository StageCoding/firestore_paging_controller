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
      when(mockDocumentSnapshot.id).thenReturn(data['age'].toString());
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

  test('order multiple queries - first visible only', () async {
    final list = List.generate(
      100,
      (i) => {
        'age': i,
        'gender': i % 2 == 0 ? 'male' : 'female',
        'country': switch (i % 3) {
          0 => 'USA',
          1 => 'UK',
          _ => 'Canada',
        },
      },
    ).map((data) {
      final mockDocumentSnapshot = MockQueryDocumentSnapshot();
      when(mockDocumentSnapshot.get('age')).thenReturn(data['age']);
      when(mockDocumentSnapshot.data()).thenReturn(data);
      return mockDocumentSnapshot;
    }).toList();

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      queryBuilders: [
        (query) {
          final mockQuery = MockQuery();
          final snapshot = MockQuerySnapshot();

          when(snapshot.docs).thenReturn(list
              .where((e) => e.data()['gender'] == 'male')
              .take(10)
              .toList());

          when(mockQuery.get()).thenAnswer((_) async => Future.value(snapshot));

          when(convertedMockCollectionReference.orderBy('age',
                  descending: false))
              .thenReturn(mockQuery);

          when(mockQuery.limit(10)).thenReturn(mockQuery);

          return query;
        },
        (query) {
          final mockQuery = MockQuery();
          final snapshot = MockQuerySnapshot();

          when(snapshot.docs).thenReturn(list
              .where((e) => e.data()['country'] == 'UK')
              .skip(18)
              .take(10)
              .toList());

          when(mockQuery.get()).thenAnswer((_) async => Future.value(snapshot));

          when(convertedMockCollectionReference.orderBy('age',
                  descending: false))
              .thenReturn(mockQuery);

          when(mockQuery.limit(10)).thenReturn(mockQuery);

          return query;
        },
      ],
      orderBy: 'age',
    );

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList,
        list.where((e) => e.data()['gender'] == 'male').take(10).toList());
    expect(controller.value.nextPageKey, 1);
  });

  test('order two queries - interlocking - twice', () async {
    final mockQuery1 = MockQuery();
    final snapshot1 = MockQuerySnapshot();
    when(mockQuery1.get()).thenAnswer((_) async => Future.value(snapshot1));
    when(mockQuery1.parameters).thenReturn({'orderBy': [], 'limit': []});
    when(mockQuery1.orderBy('age', descending: false)).thenReturn(mockQuery1);
    when(mockQuery1.limit(any)).thenReturn(mockQuery1);
    when(mockQuery1.startAfterDocument(any)).thenReturn(mockQuery1);

    final mockQuery2 = MockQuery();
    final snapshot2 = MockQuerySnapshot();
    when(mockQuery2.get()).thenAnswer((_) async => Future.value(snapshot2));
    when(mockQuery2.parameters).thenReturn({'orderBy': [], 'limit': []});
    when(mockQuery2.orderBy('age', descending: false)).thenReturn(mockQuery2);
    when(mockQuery2.limit(any)).thenReturn(mockQuery2);
    when(mockQuery2.startAfterDocument(any)).thenReturn(mockQuery2);

    final list = List.generate(
      100,
      (i) => {
        'age': i,
        'gender': i % 2 == 0 ? 'male' : 'female',
        'country': switch (i % 3) {
          0 => 'USA',
          1 => 'UK',
          _ => 'Canada',
        },
      },
    ).map((data) {
      final mockDocumentSnapshot = MockQueryDocumentSnapshot();
      when(mockDocumentSnapshot.id).thenReturn(data['age'].toString());
      when(mockDocumentSnapshot.get('age')).thenReturn(data['age']);
      when(mockDocumentSnapshot.data()).thenReturn(data);
      return mockDocumentSnapshot;
    }).toList();

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      queryBuilders: [
        (query) => mockQuery1,
        (query) => mockQuery2,
      ],
      orderBy: 'age',
    );

    when(snapshot1.docs).thenReturn(
      list.where((e) => e.data()['gender'] == 'male').take(10).toList(),
    );

    when(snapshot2.docs).thenReturn(list
        .where((e) => e.data()['country'] == 'UK')
        .skip(3)
        .take(10)
        .toList());

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, [
      list[0],
      list[2],
      list[4],
      list[6],
      list[8],
      list[10],
      list[12],
      list[13],
      list[14],
      list[16],
      list[18],
    ]);
    expect(controller.value.nextPageKey, 1);

    when(snapshot1.docs).thenReturn(list
        .where((e) => e.data()['gender'] == 'male')
        .skip(10)
        .take(10)
        .toList());

    when(snapshot2.docs).thenReturn(list
        .where((e) => e.data()['country'] == 'UK')
        .skip(13)
        .take(10)
        .toList());

    controller.notifyPageRequestListeners(1);

    await Future.delayed(const Duration(milliseconds: 10));

    expect(controller.error, isNull);
    expect(controller.itemList, [
      list[0],
      list[2],
      list[4],
      list[6],
      list[8],
      list[10],
      list[12],
      list[13],
      list[14],
      list[16],
      list[18],
      list[19],
      list[20],
      list[22],
      list[24],
      list[25],
      list[26],
      list[28],
      list[30],
      list[31],
      list[32],
      list[34],
      list[36],
      list[37],
      list[38],
    ]);
  });

  test('order multiple queries - interlocking - twice', () async {
    final mockQuery1 = MockQuery();
    final snapshot1 = MockQuerySnapshot();
    when(mockQuery1.get()).thenAnswer((_) async => Future.value(snapshot1));
    when(mockQuery1.parameters).thenReturn({'orderBy': [], 'limit': []});
    when(mockQuery1.orderBy('age', descending: false)).thenReturn(mockQuery1);
    when(mockQuery1.startAfterDocument(any)).thenReturn(mockQuery1);

    final mockQuery2 = MockQuery();
    final snapshot2 = MockQuerySnapshot();
    when(mockQuery2.get()).thenAnswer((_) async => Future.value(snapshot2));
    when(mockQuery2.parameters).thenReturn({'orderBy': [], 'limit': []});
    when(mockQuery2.orderBy('age', descending: false)).thenReturn(mockQuery2);
    when(mockQuery2.startAfterDocument(any)).thenReturn(mockQuery2);

    final mockQuery3 = MockQuery();
    final snapshot3 = MockQuerySnapshot();
    when(mockQuery3.get()).thenAnswer((_) async => Future.value(snapshot3));
    when(mockQuery3.parameters).thenReturn({'orderBy': [], 'limit': []});
    when(mockQuery3.orderBy('age', descending: false)).thenReturn(mockQuery3);
    when(mockQuery3.startAfterDocument(any)).thenReturn(mockQuery3);

    final list = List.generate(
      20,
      (i) => {
        'age': i,
        'gender': i % 2 == 0 ? 'male' : 'female',
        'country': switch (i % 3) {
          0 => 'USA',
          1 => 'UK',
          _ => 'Canada',
        },
      },
    ).map((data) {
      final mockDocumentSnapshot = MockQueryDocumentSnapshot();
      when(mockDocumentSnapshot.id).thenReturn(data['age'].toString());
      when(mockDocumentSnapshot.get('age')).thenReturn(data['age']);
      when(mockDocumentSnapshot.data()).thenReturn(data);
      return mockDocumentSnapshot;
    }).toList();

    final controller = FirestorePagingController.withoutType(
      basePath: 'users',
      firestore: mockFirestore,
      queryBuilders: [
        (query) => mockQuery1,
        (query) => mockQuery2,
        (query) => mockQuery3,
      ],
      orderBy: 'age',
      pageSize: 3,
    );

    when(snapshot1.docs).thenReturn(
        list.where((e) => e.data()['gender'] == 'female').take(3).toList());
    when(mockQuery1.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 3);
      return mockQuery1;
    });

    when(snapshot2.docs).thenReturn(list
        .where((e) => e.data()['country'] == 'USA')
        .skip(1)
        .take(3)
        .toList());
    when(mockQuery2.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 3);
      return mockQuery2;
    });

    when(snapshot3.docs)
        .thenReturn(list.where((e) => e.data()['age'] > 10).take(3).toList());
    when(mockQuery3.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 3);
      return mockQuery3;
    });

    controller.notifyPageRequestListeners(0);

    await Future.delayed(const Duration(milliseconds: 10));

    // First query: 1, 3, 5
    // Second query: (0 skipped) 3, 6, 9
    // Third query: 11, 12, 13

    expect(controller.error, isNull);
    expect(controller.itemList, [
      list[1],
      list[3],
      list[5],
    ]);
    expect(controller.value.nextPageKey, 1);

    when(snapshot1.docs).thenReturn(list
        .where((e) => e.data()['gender'] == 'female')
        .skip(3)
        .take(3)
        .toList());
    when(mockQuery1.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 3);
      return mockQuery1;
    });

    when(snapshot2.docs).thenReturn(list
        .where((e) => e.data()['country'] == 'USA')
        .skip(1)
        .skip(3)
        .take(1)
        .toList());
    when(mockQuery2.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 1);
      return mockQuery2;
    });

    when(snapshot3.docs).thenReturn([]);
    when(mockQuery3.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 0);
      return mockQuery3;
    });

    controller.notifyPageRequestListeners(1);

    await Future.delayed(const Duration(milliseconds: 10));

    // First query: 7, 9, 11
    // Second query: 6, 9, 12
    // Third query: 11, 12, 13

    expect(controller.error, isNull);
    expect(controller.itemList, [
      list[1],
      list[3],
      list[5],
      list[6],
      list[7],
      list[9],
      list[11],
    ]);
    expect(controller.value.nextPageKey, 2);

    when(snapshot1.docs).thenReturn(list
        .where((e) => e.data()['gender'] == 'female')
        .skip(6)
        .take(3)
        .toList());
    when(mockQuery1.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 3);
      return mockQuery1;
    });

    when(snapshot2.docs).thenReturn(list
        .where((e) => e.data()['country'] == 'USA')
        .skip(1)
        .skip(4)
        .take(2)
        .toList());
    when(mockQuery2.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 2);
      return mockQuery2;
    });

    when(snapshot3.docs).thenReturn(
        list.where((e) => e.data()['age'] > 10).skip(3).take(1).toList());
    when(mockQuery3.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 1);
      return mockQuery3;
    });

    controller.notifyPageRequestListeners(2);

    await Future.delayed(const Duration(milliseconds: 10));

    // First query: 13, 15, 17
    // Second query: 12, 15, 18
    // Third query: 12, 13, 14

    expect(controller.error, isNull);
    expect(controller.itemList, [
      list[1],
      list[3],
      list[5],
      list[6],
      list[7],
      list[9],
      list[11],
      list[12],
      list[13],
      list[14],
    ]);
    expect(controller.value.nextPageKey, 3);

    when(snapshot1.docs).thenReturn(list
        .where((e) => e.data()['gender'] == 'female')
        .skip(9)
        .take(1)
        .toList());
    when(mockQuery1.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 1);
      return mockQuery1;
    });

    when(snapshot2.docs).thenReturn(list
        .where((e) => e.data()['country'] == 'USA')
        .skip(1)
        .skip(6)
        .take(1)
        .toList());
    when(mockQuery2.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 1);
      return mockQuery2;
    });

    when(snapshot3.docs).thenReturn(
        list.where((e) => e.data()['age'] > 10).skip(4).take(3).toList());
    when(mockQuery3.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 3);
      return mockQuery3;
    });

    controller.notifyPageRequestListeners(3);

    await Future.delayed(const Duration(milliseconds: 10));

    // First query: 15, 17, 19
    // Second query: 15, 18, (no more items)
    // Third query: 15, 16, 17

    expect(controller.error, isNull);
    expect(controller.itemList, [
      list[1],
      list[3],
      list[5],
      list[6],
      list[7],
      list[9],
      list[11],
      list[12],
      list[13],
      list[14],
      list[15],
      list[16],
      list[17],
    ]);
    expect(controller.value.nextPageKey, 4);

    when(snapshot1.docs).thenReturn(list
        .where((e) => e.data()['gender'] == 'female')
        .skip(10)
        .take(2)
        .toList());
    when(mockQuery1.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 2);
      return mockQuery1;
    });

    when(snapshot2.docs).thenReturn(list
        .where((e) => e.data()['country'] == 'USA')
        .skip(1)
        .skip(7)
        .take(2)
        .toList());
    when(mockQuery2.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 2);
      return mockQuery2;
    });

    when(snapshot3.docs).thenReturn(
        list.where((e) => e.data()['age'] > 10).skip(7).take(3).toList());
    when(mockQuery3.limit(any)).thenAnswer((invocation) {
      assert(invocation.positionalArguments[0] == 3);
      return mockQuery3;
    });

    controller.notifyPageRequestListeners(4);

    await Future.delayed(const Duration(milliseconds: 10));

    // First query: 19 (no more items)
    // Second query: 18 (no more items)
    // Third query: 18, 19 (no more items)

    expect(controller.error, isNull);
    expect(controller.itemList, [
      list[1],
      list[3],
      list[5],
      list[6],
      list[7],
      list[9],
      list[11],
      list[12],
      list[13],
      list[14],
      list[15],
      list[16],
      list[17],
      list[18],
      list[19],
    ]);
    expect(controller.value.nextPageKey, isNull);
  });
}
