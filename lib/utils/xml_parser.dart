import 'dart:io';
import 'package:xml/xml.dart';
import 'package:notas_tigre/models/nota.dart'; // Importa os modelos
import 'dart:convert'; // Para jsonEncode

class XmlParser {
  static final Map<String, String> ns = {"ns": "http://www.portalfiscal.inf.br/nfe"};

  // Adaptação de extrair_produtos_infCpl
  static List<Produto> _extractProductsFromInfCpl(XmlElement xmlRoot) {
    final products = <Produto>[];
    final infCplElement = xmlRoot.findAllElements("infCpl", namespace: ns['ns']).firstWhere(
      (element) => true, // Encontra o primeiro que existe
      orElse: () => null!, // Retorna null se não encontrar
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
            valorUnitario: 0.0, // Valor unitário não está no infCpl, manter 0
          ));
        } catch (e) {
          print('Erro ao converter quantidade $quantidadeStr para double: $e');
        }
      }
    }
    return products;
  }

  // Adaptação de extrair_dados_nota
  static Map<String, dynamic> _extractNoteData(String xmlContent) {
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
      "Produtos": produtosInfCpl.map((p) => p.toJson()).toList(), // Converte Produtos para Map
      "Nota Mae Numero": notaMaeNumero, // Adiciona o número da nota mãe para fácil acesso
    };
  }

  // Adaptação de atualizar_produtos_restantes
  static List<Produto> _updateRemainingProducts(List<Produto> remainingProducts, List<Produto> childProducts) {
    final updatedProducts = <Produto>[];
    final remainingMap = { for (var p in remainingProducts) p.codigo.lstrip('0'): p.quantidade };

    for (var childProduct in childProducts) {
      final childCode = childProduct.codigo.lstrip('0');
      if (remainingMap.containsKey(childCode)) {
        remainingMap[childCode] = (remainingMap[childCode] ?? 0.0) - childProduct.quantidade;
      } else {
        print('⚠️ Aviso: Produto ${childCode} da nota filha não encontrado na nota mãe!');
      }
    }

    remainingProducts.forEach((product) {
      final code = product.codigo.lstrip('0');
      final updatedQuantity = remainingMap[code] ?? product.quantidade;
      if (updatedQuantity > 0) {
        updatedProducts.add(Produto(
          codigo: product.codigo,
          descricao: product.descricao,
          quantidade: updatedQuantity,
          unidade: product.unidade,
          valorUnitario: product.valorUnitario,
        ));
      }
    });

    return updatedProducts;
  }

  // Adaptação de processar_nota
  static Future<Nota> processAndSaveNote(String xmlContent, List<Nota> notesList) async {
    final noteData = _extractNoteData(xmlContent);
    final numeroNota = noteData['Número da Nota'] as String;
    final cfop = noteData['CFOP'] as String;
    final notaMaeNumero = noteData['Nota Mae Numero'] as String?;

    if (cfop == "5922") { // Nota Mãe
      final Nota newNota = Nota(
        numeroNota: numeroNota,
        cfop: cfop,
        total: noteData['Total'] as double,
        informacoesAdicionais: noteData['Informações Adicionais'] as String,
        produtos: (noteData['Produtos'] as List).map((p) => Produto.fromJson(p)).toList(),
        produtosRestantes: (noteData['Produtos'] as List).map((p) => Produto.fromJson(p)).toList(),
        notasFilhas: [],
      );

      // Procura se já existe, se sim, atualiza; senão, adiciona
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
        // Cria uma cópia da nota mãe para modificação
        motherNote = Nota(
          numeroNota: motherNote.numeroNota,
          cfop: motherNote.cfop,
          total: motherNote.total,
          informacoesAdicionais: motherNote.informacoesAdicionais,
          produtos: motherNote.produtos,
          produtosRestantes: List.from(motherNote.produtosRestantes), // Cópia para modificar
          notasFilhas: List.from(motherNote.notasFilhas), // Cópia para modificar
        );
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
        notesList.add(motherNote); // Adiciona o placeholder
        motherNoteIndex = notesList.indexOf(motherNote); // Pega o índice da nova nota mãe
      }

      // Converte a lista de produtos do mapa para objetos Produto
      final List<Produto> childProductsList = (noteData['Produtos'] as List)
          .map((p) => Produto.fromJson(p)).toList();

      // Atualiza produtos restantes da nota mãe
      motherNote.produtosRestantes.clear(); // Limpa e preenche com os atualizados
      motherNote.produtosRestantes.addAll(_updateRemainingProducts(motherNote.produtos, childProductsList));


      // Verifica se a Nota Filha já foi adicionada
      final Nota newChildNota = Nota(
        numeroNota: numeroNota,
        cfop: cfop,
        total: noteData['Total'] as double,
        informacoesAdicionais: noteData['Informações Adicionais'] as String,
        produtos: childProductsList,
        notaMaeNumero: notaMaeNumero,
      );

      if (!motherNote.notasFilhas.any((nf) => nf.numeroNota == numeroNota)) {
        motherNote.notasFilhas.add(newChildNota);
        notesList[motherNoteIndex] = motherNote; // Atualiza a nota mãe na lista
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