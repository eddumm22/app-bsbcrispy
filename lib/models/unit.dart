class Unit {
  Unit({
    required this.id,
    required this.name,
    required this.cnpj,
  });

  final String id;
  final String name;
  final String cnpj;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cnpj': cnpj,
    };
  }

  static Unit fromDoc(String id, Map<String, dynamic> data) {
    return Unit(
      id: id,
      name: data['name'] as String? ?? '',
      cnpj: data['cnpj'] as String? ?? '',
    );
  }
}

