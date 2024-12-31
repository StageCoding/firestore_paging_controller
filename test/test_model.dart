class TestModel {
  final String name;
  final int age;

  TestModel({
    required this.name,
    required this.age,
  });

  @override
  int get hashCode => name.hashCode ^ age.hashCode;

  @override
  operator ==(Object other) =>
      other is TestModel && other.name == name && other.age == age;

  static fromMap(Map<String, dynamic> map) => TestModel(
        name: map['name'] as String,
        age: map['age'] as int,
      );
}
