import 'dart:io';

import 'package:notas_tigre/models/nota.dart';
import 'package:flutter/material.dart'; // Para debug ou logs, se necessário

class PdfParser {
  // Regex para extrair Código e Valor Unitário.
  // Baseado na estrutura do PDF da TIGRE (Pedido Número 4652917) onde:
  // Coluna 4 (Material/Código) e Coluna 7 (Valor Unit)
  // Utilizamos uma regex que busca uma linha de dados com dígitos, descrição e valor unitário.
  // Padrão do PDF (simplificado): "000" | "Item" | "Material" | "Descrição" | ... | "Quantidade" | "Valor Unit"
  // O valor unitário é a 7ª coluna de dados. A regex busca pelo código do material e o Valor Unit no final da linha.

  // Regex projetada para capturar linhas de itens tabulares, onde:
  // Grupo 1: Captura o Código do Material (ex: 34652686)
  // Grupo 2: Captura o Valor Unitário (ex: 1,18 ou 25.07)




  static final RegExp _itemRegex = RegExp(
    r'"\d{3}",\s*"\d+",\s*"(.*?)"\s*,\s*".*?"\s*,\s*".*?"\s*,\s*".*?"\s*,\s*"([\d,.]+)"',
    multiLine: true,
);
  /// Extrai códigos de produto e seus respectivos valores unitários a partir
  /// do texto do pedido (PDF copiado ou TXT).
  /// Retorna um mapa onde a chave é o código do produto (sem zeros à esquerda)
  /// e o valor é o preço unitário.
  static String getPdfText(File file){
    String pdfText = '';
    try {
      pdfText = file.readAsStringSync();
    } catch (e) {
      debugPrint('Erro ao ler o arquivo PDF: $e');
    }
    return pdfText;
  }
  static Map<String, double> extractValuesFromText(String pdfText) {
    final Map<String, double> priceMap = {};

    // Remove espaços e novas linhas extras para normalizar o texto copiado do PDF
    String normalizedText = pdfText.replaceAll(RegExp(r'\s+'), ' ').trim();

    final matches = _itemRegex.allMatches(normalizedText);

    if (matches.isEmpty) {
      debugPrint('Nenhuma correspondência encontrada no texto do PDF.');
      // Tenta uma regex mais simples como fallback, baseada em um formato mais aberto de texto
      final simpleRegex = RegExp(r"(\d+)\s+[^@\n]+?\s+([\d\.]+,\d+|\d+\.\d+|\d+)");
      final simpleMatches = simpleRegex.allMatches(pdfText);

      for (final match in simpleMatches) {
        final code = match.group(1)?.lstripAllZeros() ?? '';
        final priceStr = match.group(2)?.replaceAll('.', '').replaceAll(',', '.') ?? '0.0';
        final price = double.tryParse(priceStr);

        if (code.isNotEmpty && price != null && price > 0.0) {
          // A regex simples é muito genérica, usamos apenas como último recurso se a primeira falhar.
          // Em um app de produção, usaríamos uma biblioteca de parsing de PDF real.
          if (!priceMap.containsKey(code)) { // Garante que a primeira correspondência seja a priorizada
            priceMap[code] = price;
          }
        }
      }
    } else {
      // Usa a regex principal (específica para o formato tabular do PDF da Tigre)
      for (final match in matches) {
        final code = match.group(1)?.lstripAllZeros() ?? '';
        final priceStr = match.group(2)?.replaceAll('.', '').replaceAll(',', '.') ?? '0.0';
        final price = double.tryParse(priceStr);

        if (code.isNotEmpty && price != null) {
          priceMap[code] = price;
          print("Codigo:$code");
          print("Valor:$price");
        }
      }
    }

    return priceMap;
  }
}