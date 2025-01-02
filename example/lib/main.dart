import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:example/database/firebase.dart';
import 'package:flutter/material.dart';
import 'package:firestore_paging_controller/firestore_paging_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  // fillDatabase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // This controller will fetch user if it is either a male or older than 50
  final controller = FirestorePagingController.withoutType(
    basePath: 'users',
    pageSize: 10,
    orderBy: 'age',
    queryBuilders: [
      (query) => query.where('age', isGreaterThan: 50),
      (query) => query.where('gender', isEqualTo: 'male'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: PagedListView(
          pagingController: controller,
          builderDelegate: PagedChildBuilderDelegate<
              QueryDocumentSnapshot<Map<String, dynamic>>>(
            itemBuilder: (context, item, index) {
              return ListTile(
                title: Text(
                  'Age: ${item['age']} - Country: ${item['country']}',
                ),
                subtitle: Text('Gender: ${item['gender']}'),
              );
            },
          ),
        ),
      ),
    );
  }
}
