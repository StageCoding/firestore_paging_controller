import 'package:cloud_firestore/cloud_firestore.dart';

void fillDatabase() {
  print('Filling the database');

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
  );

  for (final item in list) {
    FirebaseFirestore.instance.collection('users').add(item);
  }

  print('Database filled');
}
