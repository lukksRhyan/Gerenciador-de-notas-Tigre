// Classe para representar um produto dentro de uma nota
class Produto {
  final String codigo;
  final String descricao;
  final double quantidade;
  final String unidade;
  final double valorUnitario;

  Produto({
    required this.codigo,
    required this.descricao,
    required this.quantidade,
    required this.unidade,
    this.valorUnitario = 0.0,
  });

  // Converte um mapa (JSON) em um objeto Produto
  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      codigo: json['Código']?.toString() ?? '',
      descricao: json['Descrição']?.toString() ?? '',
      quantidade: double.tryParse(json['Quantidade']?.toString() ?? '0.0') ?? 0.0,
      unidade: json['Unidade']?.toString() ?? '',
      valorUnitario: double.tryParse(json['Valor Unitário']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  // Converte um objeto Produto em um mapa (para salvar/passar dados)
  Map<String, dynamic> toJson() {
    return {
      'Código': codigo,
      'Descrição': descricao,
      'Quantidade': quantidade,
      'Unidade': unidade,
      'Valor Unitário': valorUnitario,
    };
  }

  // NOVO: Método copyWith para criar uma nova instância com valores atualizados
  Produto copyWith({
    String? codigo,
    String? descricao,
    double? quantidade,
    String? unidade,
    double? valorUnitario,
  }) {
    return Produto(
      codigo: codigo ?? this.codigo,
      descricao: descricao ?? this.descricao,
      quantidade: quantidade ?? this.quantidade,
      unidade: unidade ?? this.unidade,
      valorUnitario: valorUnitario ?? this.valorUnitario,
    );
  }
}

// Classe principal para representar uma Nota Fiscal
class Nota {
  final String numeroNota;
  final String cfop;
  final double total;
  final String informacoesAdicionais;
  final List<Produto> produtos;
  final List<Produto> produtosRestantes;
  final List<Nota> notasFilhas;
  final String? notaMaeNumero;
  final bool completa; // NOVO

  Nota({
    required this.numeroNota,
    required this.cfop,
    required this.total,
    this.informacoesAdicionais = '',
    required this.produtos,
    this.produtosRestantes = const [],
    this.notasFilhas = const [],
    this.notaMaeNumero,
    this.completa = false, // NOVO
  });

  // Converte um mapa (JSON) em um objeto Nota
  factory Nota.fromJson(Map<String, dynamic> json) {
    var produtosList = <Produto>[];
    if (json['Produtos'] is List) {
      produtosList = (json['Produtos'] as List)
          .map((i) => Produto.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    var produtosRestantesList = <Produto>[];
    // products_restantes no JSON pode ser uma string se vier do raw_json_data do backend (não mais usado aqui)
    // ou uma lista de mapas se for diretamente do XML_parser.dart
    if (json['produtos_restantes'] is List) {
      produtosRestantesList = (json['produtos_restantes'] as List)
          .map((i) => Produto.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    var notasFilhasList = <Nota>[];
    if (json['notas_filhas'] is List) {
      notasFilhasList = (json['notas_filhas'] as List)
          .map((i) => Nota.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return Nota(
      numeroNota: json['Número da Nota']?.toString() ?? '',
      cfop: json['CFOP']?.toString() ?? '',
      total: double.tryParse(json['Total']?.toString() ?? '0.0') ?? 0.0,
      informacoesAdicionais: json['Informações Adicionais']?.toString() ?? '',
      produtos: produtosList,
      produtosRestantes: produtosRestantesList,
      notasFilhas: notasFilhasList,
      notaMaeNumero: json['Nota Mae Numero']?.toString(),
      completa: json['completa'] == true, // NOVO
    );
  }
  double get totalRestante {
    if (cfop != "5922") return 0.0; // Apenas notas mãe têm total restante

    double filhosTotal = notasFilhas.fold(0.0, (sum, nf) => sum + nf.total);
    return total - filhosTotal;
  }
  // Converte um objeto Nota em um mapa (para salvar/passar dados)
  Map<String, dynamic> toJson() {
    return {
      'Número da Nota': numeroNota,
      'CFOP': cfop,
      'Total': total,
      'Informações Adicionais': informacoesAdicionais,
      'Produtos': produtos.map((p) => p.toJson()).toList(),
      'produtos_restantes': produtosRestantes.map((p) => p.toJson()).toList(),
      'notas_filhas': notasFilhas.map((nf) => nf.toJson()).toList(),
      'Nota Mae Numero': notaMaeNumero,
      'completa': completa, // NOVO
    };
  }

  // NOVO: Método copyWith para criar uma nova instância da Nota
  Nota copyWith({
    String? numeroNota,
    String? cfop,
    double? total,
    String? informacoesAdicionais,
    List<Produto>? produtos,
    List<Produto>? produtosRestantes,
    List<Nota>? notasFilhas,
    String? notaMaeNumero,
    bool? completa, // NOVO
  }) {
    return Nota(
      numeroNota: numeroNota ?? this.numeroNota,
      cfop: cfop ?? this.cfop,
      total: total ?? this.total,
      informacoesAdicionais: informacoesAdicionais ?? this.informacoesAdicionais,
      produtos: produtos ?? this.produtos,
      produtosRestantes: produtosRestantes ?? this.produtosRestantes,
      notasFilhas: notasFilhas ?? this.notasFilhas,
      notaMaeNumero: notaMaeNumero ?? this.notaMaeNumero,
      completa: completa ?? this.completa, // NOVO
    );
  }
}

// Extensão para String para remover zeros à esquerda
extension StringExtension on String {
  String lstrip(String chars) {
    if (chars.isEmpty) {
      return trimLeft();
    }
    int i = 0;
    while (i < length && chars.contains(this[i])) {
      i++;
    }
    return substring(i);
  }
}