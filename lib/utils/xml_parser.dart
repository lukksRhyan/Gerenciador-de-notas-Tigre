import 'dart:io';
import 'package:xml/xml.dart';
import 'package:notas_tigre/models/nota.dart';
import 'dart:convert';

class XmlParser {
  static final Map<String, String> ns = {"ns": "http://www.portalfiscal.inf.br/nfe"};

  // Adaptação de extrair_produtos_infCpl
  static List<Produto> _extractProductsFromInfCpl(XmlElement xmlRoot) {
    final products = <Produto>[];
    final infCplElement = xmlRoot.findAllElements("infCpl", namespace: ns['ns']).firstWhere(
      (element) => true,
      orElse: () => null!,
    );

    if (infCplElement != null && infCplElement.innerText.isNotEmpty) {
      final infCplText = infCplElement.innerText.trim();
      final regex = RegExp(r"(\d+)\s*@\s*([\d,.]+)\s*@\s*([^@]+?)\s*@\s*([\w]+)");
      final matches = regex.allMatches(infCplText);

      for (var match in matches) {
        final codigo = match.group(1)?.trim() ?? '';
        final quantidadeStr = match.group(2)?.trim() ?? '0';
        final descricao = match.group(3)?.trim() ?? '';
        final unidade = match.group(4)?.trim() ?? '';

        try {
          final quantidade = double.parse(quantidadeStr.replaceAll(',', '.'));
          products.add(Produto(
            codigo: codigo,
            descricao: descricao,
            quantidade: quantidade,
            unidade: unidade,
            valorUnitario: 0.0, // Valor unitário padrão 0.0
          ));
        } catch (e) {
          print('Erro ao converter quantidade $quantidadeStr para double: $e');
        }
      }
    }
    return products;
  }

  // Adaptação de extrair_dados_nota
  static Map<String, dynamic> extractNoteData(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final root = document.rootElement;

    final nNfElement = root.findAllElements("nNF", namespace: ns['ns']).firstWhere(
      (element) => true,
      orElse: () => null!,
    );
    final numeroNota = nNfElement?.innerText.lstrip('0') ?? "desconhecido";

    final vNfElement = root.findAllElements("vNF", namespace: ns['ns']).firstWhere(
      (element) => true,
      orElse: () => null!,
    );
    final valorNota = double.tryParse(vNfElement?.innerText ?? '0.0') ?? 0.0;

    final cfopElement = root.findAllElements("CFOP", namespace: ns['ns']).firstWhere(
      (element) => true,
      orElse: () => null!,
    );
    final cfop = cfopElement?.innerText ?? "0000";

    final infCplElement = root.findAllElements("infCpl", namespace: ns['ns']).firstWhere(
      (element) => true,
      orElse: () => null!,
    );
    final infCplText = infCplElement?.innerText.trim() ?? "";

    final produtosInfCpl = _extractProductsFromInfCpl(root);

    String? notaMaeNumero;
    if (cfop == "5116") {
      final match = RegExp(r"NF\s*(\d+)").firstMatch(infCplText);
      if (match != null) {
        notaMaeNumero = match.group(1)?.lstrip('0');
      }
    }

    return {
      "Número da Nota": numeroNota,
      "CFOP": cfop,
      "Informações Adicionais": infCplText,
      "Total": valorNota,
      "Produtos": produtosInfCpl.map((p) => p.toJson()).toList(),
      "Nota Mae Numero": notaMaeNumero,
    };
  }

  // Adaptação de atualizar_produtos_restantes
  static List<Produto> _updateRemainingProducts(List<Produto> motherProductsOriginal, List<Produto> childProducts) {
    final updatedProducts = <Produto>[];
    // Crie um mapa de cópias dos produtos originais da mãe para manipular as quantidades
    final Map<String, Produto> tempMotherProducts = {
      for (var p in motherProductsOriginal) p.codigo.lstrip('0'): p.copyWith() // Crie cópias
    };

    for (var childProduct in childProducts) {
      final childCode = childProduct.codigo.lstrip('0');
      if (tempMotherProducts.containsKey(childCode)) {
        Produto motherProd = tempMotherProducts[childCode]!;
        double newQuantity = motherProd.quantidade - childProduct.quantidade;
        tempMotherProducts[childCode] = motherProd.copyWith(quantidade: newQuantity);
      } else {
        print('⚠️ Aviso: Produto ${childCode} da nota filha não encontrado na nota mãe!');
      }
    }

    // Filtra e adiciona os produtos com quantidade > 0 à lista final
    tempMotherProducts.forEach((code, product) {
      if (product.quantidade > 0) {
        updatedProducts.add(product);
      }
    });

    return updatedProducts;
  }

  // Novo método para adicionar/atualizar a nota na lista em memória
  static Nota addNotaToNotesList(Map<String, dynamic> rawNoteData, List<Produto> productsWithValues, List<Nota> notesList) {
    final numeroNota = rawNoteData['Número da Nota'] as String;
    final cfop = rawNoteData['CFOP'] as String;
    final notaMaeNumero = rawNoteData['Nota Mae Numero'] as String?;

    if (cfop == "5922") { // Nota Mãe
      final Nota newNota = Nota(
        numeroNota: numeroNota,
        cfop: cfop,
        total: rawNoteData['Total'] as double,
        informacoesAdicionais: rawNoteData['Informações Adicionais'] as String,
        produtos: productsWithValues, // Use os produtos com valores unitários definidos
        produtosRestantes: List.from(productsWithValues), // Cópia inicial
        notasFilhas: [],
      );

      int existingIndex = notesList.indexWhere((n) => n.numeroNota == numeroNota);
      if (existingIndex != -1) {
        notesList[existingIndex] = newNota;
        print('✅ Nota Mãe $numeroNota atualizada na lista em memória.');
      } else {
        notesList.add(newNota);
        print('✅ Nota Mãe $numeroNota adicionada à lista em memória.');
      }
      return newNota;

    } else if (cfop == "5116" && notaMaeNumero != null) { // Nota Filha
      print('📌 Buscando Nota Mãe $notaMaeNumero na lista em memória...');
      int motherNoteIndex = notesList.indexWhere((n) => n.numeroNota == notaMaeNumero);
      Nota motherNote;

      if (motherNoteIndex != -1) {
        motherNote = notesList[motherNoteIndex];
        // Cria uma CÓPIA da nota mãe para modificação e a substitui na lista
        motherNote = Nota(
          numeroNota: motherNote.numeroNota,
          cfop: motherNote.cfop,
          total: motherNote.total,
          informacoesAdicionais: motherNote.informacoesAdicionais,
          produtos: motherNote.produtos, // Produtos originais da mãe
          produtosRestantes: _updateRemainingProducts(motherNote.produtos, productsWithValues), // Calcula novos restantes
          notasFilhas: List.from(motherNote.notasFilhas), // Cópia para adicionar a nova filha
          notaMaeNumero: motherNote.notaMaeNumero,
        );
        notesList[motherNoteIndex] = motherNote; // Atualiza a nota mãe na lista
      } else {
        print('⚠️ Nota Mãe $notaMaeNumero não encontrada. Criando placeholder.');
        motherNote = Nota(
          numeroNota: notaMaeNumero,
          cfop: "5922",
          informacoesAdicionais: "Nota Mãe criada como placeholder por nota filha processada.",
          total: 0.0,
          produtos: [],
          produtosRestantes: [],
          notasFilhas: [],
        );
        notesList.add(motherNote);
        motherNoteIndex = notesList.indexOf(motherNote); // Pega o índice da nova nota mãe
      }

      final Nota newChildNota = Nota(
        numeroNota: numeroNota,
        cfop: cfop,
        total: rawNoteData['Total'] as double,
        informacoesAdicionais: rawNoteData['Informações Adicionais'] as String,
        produtos: productsWithValues, // Produtos da nota filha
        notaMaeNumero: notaMaeNumero,
      );

      // Adiciona a nota filha à lista de notas filhas da nota mãe, se ainda não existir
      if (!motherNote.notasFilhas.any((nf) => nf.numeroNota == numeroNota)) {
        motherNote.notasFilhas.add(newChildNota);
        // Não é necessário atualizar notesList[motherNoteIndex] novamente,
        // pois a `motherNote` já é uma cópia que foi atualizada e recolocada na lista.
        print('✅ Nota Filha $numeroNota adicionada à Nota Mãe $notaMaeNumero.');
      } else {
        print('⚠️ Nota Filha $numeroNota já está presente na Nota Mãe $notaMaeNumero, não foi adicionada novamente.');
      }
      return newChildNota;
    } else {
      throw Exception('CFOP $cfop não reconhecido ou nota mãe não associada para CFOP 5116.');
    }
  }
}