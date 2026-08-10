class OfficerModel {
  final int id;
  final String name;
  final String? empId;
  final int departmentId;
  final String? contact;
  final bool isAvailable;
  final bool isDepartmentHead;
  final bool isActive;

  const OfficerModel({
    required this.id,
    required this.name,
    this.empId,
    required this.departmentId,
    this.contact,
    this.isAvailable = true,
    this.isDepartmentHead = false,
    this.isActive = true,
  });

  factory OfficerModel.fromJson(Map<String, dynamic> json) {
    return OfficerModel(
      id: json['id'] as int,
      name: json['name'] ?? '',
      empId: json['emp_id'],
      departmentId: json['department_id'] as int,
      contact: json['contact'],
      isAvailable: json['is_available'] ?? true,
      isDepartmentHead: json['is_department_head'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emp_id': empId,
      'department_id': departmentId,
      'contact': contact,
      'is_available': isAvailable,
      'is_department_head': isDepartmentHead,
      'is_active': isActive,
    };
  }
}
