class DepartmentModel {
  final int id;
  final String name;
  final String? jurisdiction;
  final String? contact;

  const DepartmentModel({
    required this.id,
    required this.name,
    this.jurisdiction,
    this.contact,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as int,
      name: json['name'] ?? '',
      jurisdiction: json['jurisdiction'],
      contact: json['contact'],
    );
  }
}
