class ReportModel {
  final int? id;
  final String ticketId;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final String category;
  final String? description;
  final String status;
  final double priorityScore;
  final int upvoteCount;
  final String? createdAt;
  final String? assignedDepartmentName;
  final String? assignedOfficerName;
  final String? assignedOfficerEmpId;
  final int? assignedDepartmentId;
  final int? assignedOfficerId;
  final String? estimatedCompletionAt;
  final String? resolvedAt;
  final String? latestResolutionPhotoUrl;
  final bool citizenVerified;
  final String? citizenFeedbackComment;
  final String? adminReviewComment;

  ReportModel({
    this.id,
    String? ticketId,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.description,
    this.status = "submitted",
    this.priorityScore = 0.0,
    this.upvoteCount = 1,
    this.createdAt,
    this.assignedDepartmentName,
    this.assignedOfficerName,
    this.assignedOfficerEmpId,
    this.assignedDepartmentId,
    this.assignedOfficerId,
    this.estimatedCompletionAt,
    this.resolvedAt,
    this.latestResolutionPhotoUrl,
    this.citizenVerified = false,
    this.citizenFeedbackComment,
    this.adminReviewComment,
  }) : ticketId = ticketId ?? (id != null ? 'JAN-${id.toString().padLeft(6, '0')}' : 'JAN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final intId = json['id'];
    final generatedTicketId = json['ticket_id'] ?? (intId != null ? 'JAN-${intId.toString().padLeft(6, '0')}' : 'JAN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

    return ReportModel(
      id: intId,
      ticketId: generatedTicketId,
      photoUrl: json['photo_url'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] ?? 'other',
      description: json['description'],
      status: json['status'] ?? 'submitted',
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? 0.0,
      upvoteCount: json['upvote_count'] ?? 1,
      createdAt: json['created_at'],
      assignedDepartmentName: json['assigned_department_name'],
      assignedOfficerName: json['assigned_officer_name'],
      assignedOfficerEmpId: json['assigned_officer_emp_id'],
      assignedDepartmentId: json['assigned_department_id'],
      assignedOfficerId: json['assigned_officer_id'],
      estimatedCompletionAt: json['estimated_completion_at'],
      resolvedAt: json['resolved_at'],
      latestResolutionPhotoUrl: json['latest_resolution_photo_url'],
      citizenVerified: json['citizen_verified'] ?? false,
      citizenFeedbackComment: json['citizen_feedback_comment'],
      adminReviewComment: json['admin_review_comment'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ticket_id': ticketId,
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'description': description,
      'status': status,
      'priority_score': priorityScore,
      'upvote_count': upvoteCount,
      'assigned_department_name': assignedDepartmentName,
      'assigned_officer_name': assignedOfficerName,
      'assigned_officer_emp_id': assignedOfficerEmpId,
      'assigned_department_id': assignedDepartmentId,
      'assigned_officer_id': assignedOfficerId,
      'estimated_completion_at': estimatedCompletionAt,
      'resolved_at': resolvedAt,
    };
  }

  ReportModel copyWith({
    int? id,
    String? ticketId,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? category,
    String? description,
    String? status,
    double? priorityScore,
    int? upvoteCount,
    String? createdAt,
    String? assignedDepartmentName,
    String? assignedOfficerName,
    String? assignedOfficerEmpId,
    int? assignedDepartmentId,
    int? assignedOfficerId,
    String? estimatedCompletionAt,
    String? resolvedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      description: description ?? this.description,
      status: status ?? this.status,
      priorityScore: priorityScore ?? this.priorityScore,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      createdAt: createdAt ?? this.createdAt,
      assignedDepartmentName:
          assignedDepartmentName ?? this.assignedDepartmentName,
      assignedOfficerName: assignedOfficerName ?? this.assignedOfficerName,
      assignedOfficerEmpId:
          assignedOfficerEmpId ?? this.assignedOfficerEmpId,
      assignedDepartmentId: assignedDepartmentId ?? this.assignedDepartmentId,
      assignedOfficerId: assignedOfficerId ?? this.assignedOfficerId,
      estimatedCompletionAt:
          estimatedCompletionAt ?? this.estimatedCompletionAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
