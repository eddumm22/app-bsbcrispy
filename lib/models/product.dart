class Product {
  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.perishable,
    required this.type,
    this.supplierId,
  });

  final String id;
  final String name;
  final String unit; // 'UND', 'KG', 'LT'
  final bool perishable; // true = sim, false = não
  final String type; // 'insumo' ou 'producao_propria'
  final String? supplierId;

  Product copyWith({
    String? id,
    String? name,
    String? unit,
    bool? perishable,
    String? type,
    String? supplierId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      perishable: perishable ?? this.perishable,
      type: type ?? this.type,
      supplierId: supplierId ?? this.supplierId,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'unit': unit,
      'perishable': perishable,
      'type': type,
    };

    if (supplierId != null) {
      map['supplierId'] = supplierId;
    }

    return map;
  }

  static Product fromDoc(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] as String? ?? '',
      unit: data['unit'] as String? ?? 'UND',
      perishable: data['perishable'] as bool? ?? false,
      type: data['type'] as String? ?? 'insumo',
      supplierId: data['supplierId'] as String?,
    );
  }
}

