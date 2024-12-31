import 'package:firestore_paging_controller/src/firestore_paging_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firestore_paging_controller/firestore_paging_controller.dart';

void main() {
  test('adds one to input values', () {
    FirestorePagingController controller = FirestorePagingController(
      basePath: 'test',
      queryBuilders: null,
      fromMap: null,
      pageSize: 10,
    );
  });
}
