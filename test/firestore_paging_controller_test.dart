import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_paging_controller/src/firestore_paging_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firestore_paging_controller/firestore_paging_controller.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<StringMap>>(),
])
import 'firestore_paging_controller_test.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();

    final mockCollectionReference = MockCollectionReference();
    final convertedMockCollectionReference = MockCollectionReference();

    when(mockCollectionReference.withConverter<StringMap>(
      fromFirestore: anyNamed('fromFirestore'),
      toFirestore: anyNamed('toFirestore'),
    )).thenReturn(convertedMockCollectionReference);

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

  // test('FirestorePagingController converted constructor', () {
  //   final controller = FirestorePagingController.converted(
  //     basePath: 'users',
  //     firestore: mockFirestore,
  //     fromMap: (data) => data as int,
  //   );

  //   expect(controller.basePath, 'users');
  //   expect(controller.firestore, mockFirestore);
  //   expect(controller.pageSize, 10);
  // });
}
