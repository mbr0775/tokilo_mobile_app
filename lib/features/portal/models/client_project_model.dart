// lib/features/portal/models/client_project_model.dart

class ClientProjectModel {
  final String  id;
  final String  clientId;
  final String  clientEmail;
  final String? clientName;

  // Request info
  final String  requestType;   // 'service' | 'product' | 'custom'
  final String? serviceId;
  final String? productId;
  final String  title;
  final String? description;
  final String? customNotes;

  // Admin-managed
  final String  status;        // pending | approved | in_progress | completed | rejected
  final int     progress;      // 0–100
  final String? adminNotes;
  final String? invoiceUrl;
  final String? invoiceLabel;

  final DateTime createdAt;
  final DateTime updatedAt;

  ClientProjectModel({
    required this.id,
    required this.clientId,
    required this.clientEmail,
    this.clientName,
    required this.requestType,
    this.serviceId,
    this.productId,
    required this.title,
    this.description,
    this.customNotes,
    required this.status,
    required this.progress,
    this.adminNotes,
    this.invoiceUrl,
    this.invoiceLabel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClientProjectModel.fromMap(Map<String, dynamic> m) {
    return ClientProjectModel(
      id:           m['id']           ?? '',
      clientId:     m['client_id']    ?? '',
      clientEmail:  m['client_email'] ?? '',
      clientName:   m['client_name'],
      requestType:  m['request_type'] ?? 'custom',
      serviceId:    m['service_id'],
      productId:    m['product_id'],
      title:        m['title']        ?? '',
      description:  m['description'],
      customNotes:  m['custom_notes'],
      status:       m['status']       ?? 'pending',
      progress:     (m['progress'] as num?)?.toInt() ?? 0,
      adminNotes:   m['admin_notes'],
      invoiceUrl:   m['invoice_url'],
      invoiceLabel: m['invoice_label'],
      createdAt:    DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:    DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'client_id':    clientId,
    'client_email': clientEmail,
    'client_name':  clientName,
    'request_type': requestType,
    'service_id':   serviceId,
    'product_id':   productId,
    'title':        title,
    'description':  description,
    'custom_notes': customNotes,
    'status':       'pending',
    'progress':     0,
  };

  // ── Helpers ──────────────────────────────────────────────
  String get statusLabel {
    switch (status) {
      case 'pending':     return 'Pending Review';
      case 'approved':    return 'Approved';
      case 'in_progress': return 'In Progress';
      case 'completed':   return 'Completed';
      case 'rejected':    return 'Rejected';
      default:            return status;
    }
  }

  String get statusColorHex {
    switch (status) {
      case 'pending':     return 'F59E0B';
      case 'approved':    return '3B82F6';
      case 'in_progress': return '8B5CF6';
      case 'completed':   return '10B981';
      case 'rejected':    return 'EF4444';
      default:            return '64748B';
    }
  }

  String get requestTypeLabel {
    switch (requestType) {
      case 'service': return 'Service Request';
      case 'product': return 'Product Request';
      default:        return 'Custom Request';
    }
  }
}