import 'dart:convert'; // Para jsonDecode
import 'package:intl/intl.dart';
// Classe para representar um produto dentro de uma nota
class Produto {
  final String codigo;
  final String descricao;
  final double quantidade;
  final String unidade;
  final double valorUnitario; // Adicionado para manter a consistência com Excel

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
}

// Classe principal para representar uma Nota Fiscal
class Nota {
  final String numeroNota;
  final String cfop;
  final double total;
  final String informacoesAdicionais;
  final List<Produto> produtos; // Produtos da nota principal
  final List<Produto> produtosRestantes; // Para notas mãe
  final List<Nota> notasFilhas; // Para notas mãe
  final String? notaMaeNumero; // Para notas filhas

  Nota({
    required this.numeroNota,
    required this.cfop,
    required this.total,
    this.informacoesAdicionais = '',
    required this.produtos,
    this.produtosRestantes = const [],
    this.notasFilhas = const [],
    this.notaMaeNumero,
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
    if (json['produtos_restantes'] is List) {
      produtosRestantesList = (json['produtos_restantes'] as List)
          .map((i) => Produto.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    var notasFilhasList = <Nota>[];
    if (json['notas_filhas'] is List) {
      notasFilhasList = (json['notas_filhas'] as List)
          .map((i) => Nota.fromJson(i as Map<String, dynamic>)) // Recursivo
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
      notaMaeNumero: json['Nota Mae Numero']?.toString(), // Campo para referência
    );
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
    };
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