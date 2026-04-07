class Supplier {
  Supplier({
    required this.id,
    required this.legalName,
    required this.cnpj,
  });

  final String id;
  final String legalName; // Razão Social
  final String cnpj;

  Map<String, dynamic> toMap() {
    return {
      'legalName': legalName,
      'cnpj': cnpj,
    };
  }

  static Supplier fromDoc(String id, Map<String, dynamic> data) {
    return Supplier(
      id: id,
      legalName: data['legalName'] as String? ?? '',
      cnpj: data['cnpj'] as String? ?? '',
    );
  }
}

