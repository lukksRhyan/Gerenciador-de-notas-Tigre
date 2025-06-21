// lib/utils/excel_generator.dart
import 'dart:typed_data';
import 'package:excel/excel.dart'; // Importa o pacote Excel
import 'package:notas_tigre/models/nota.dart'; // Importa o modelo Nota

class ExcelGenerator {
  static Future<List<int>> generateExcelData(Nota nota) async {
    var excel = Excel.createExcel();

    // ===== PLANILHA NOTA PRINCIPAL (Mãe ou Filha) =====
    // O nome da planilha depende se a nota é mãe ou filha
    String sheetTitle = nota.cfop == "5922" ? "Nota Mãe" : "Detalhes da Nota";
    Sheet sheet = excel[sheetTitle]!; // Use ! para assumir que a sheet existe ou que será criada
    excel.setDefaultSheet(sheetTitle); // Define como a primeira folha visível

    sheet.appendRow([TextCellValue("SGNT - Criado por Lucas Rhyan")]);
    sheet.appendRow([]); // Linha em branco

    sheet.appendRow([TextCellValue("Número da Nota"), TextCellValue(nota.numeroNota)]);
    sheet.appendRow([TextCellValue("CFOP"), TextCellValue(nota.cfop)]);
    sheet.appendRow([TextCellValue("Total"), TextCellValue("R\$${nota.total.toStringAsFixed(2)}")]);
    sheet.appendRow([]);
    sheet.appendRow([]); // Linha em branco

    // Cabeçalho dos produtos
    sheet.appendRow([
      TextCellValue("Código"), TextCellValue("Descrição"), TextCellValue("Quantidade"),
      TextCellValue("Unidade"), TextCellValue("Valor Unitário"), TextCellValue("Total"),
      TextCellValue("Base de Cálculo"), TextCellValue("ICMS")
    ]);

    int startRow = sheet.maxRows + 1; // Próxima linha disponível
    for (var i = 0; i < nota.produtos.length; i++) {
      final produto = nota.produtos[i];
      int currentRow = startRow + i;
      sheet.appendRow([
        TextCellValue(produto.codigo.lstrip('0')),
        TextCellValue(produto.descricao),
        DoubleCellValue(produto.quantidade),
        TextCellValue(produto.unidade),
        DoubleCellValue(produto.valorUnitario),
        FormulaCellValue("C${currentRow}*E${currentRow}"), // Total (Qtd * Vlr Unit)
        FormulaCellValue("F${currentRow}*0.2732"), // Base de Cálculo
        FormulaCellValue("G${currentRow}*0.205"), // ICMS
      ]);
    }
    _adjustColumnWidths(sheet);


    // ===== PLANILHA NOTAS FILHAS (se for nota mãe) =====
    if (nota.cfop == "5922" && nota.notasFilhas.isNotEmpty) {
      for (var i = 0; i < nota.notasFilhas.length; i++) {
        final notaFilha = nota.notasFilhas[i];
        String childSheetTitle = "Nota Filha ${i + 1}";
        Sheet childSheet = excel[childSheetTitle]!; // Use ! para assumir que a sheet existe ou que será criada

        childSheet.appendRow([TextCellValue("Número da Nota"), TextCellValue(notaFilha.numeroNota)]);
        childSheet.appendRow([TextCellValue("CFOP"), TextCellValue(notaFilha.cfop)]);
        childSheet.appendRow([TextCellValue("Total"), TextCellValue("R\$${notaFilha.total.toStringAsFixed(2)}")]);
        childSheet.appendRow([]);
        childSheet.appendRow([]);

        childSheet.appendRow([
          TextCellValue("Código"), TextCellValue("Descrição"), TextCellValue("Quantidade"),
          TextCellValue("Unidade"), TextCellValue("Valor Unitário"), TextCellValue("Total"),
          TextCellValue("Base de Cálculo"), TextCellValue("ICMS")
        ]);

        int childStartRow = childSheet.maxRows + 1;
        for (var j = 0; j < notaFilha.produtos.length; j++) {
          final produto = notaFilha.produtos[j];
          int currentChildRow = childStartRow + j;
          childSheet.appendRow([
            TextCellValue(produto.codigo.lstrip('0')),
            TextCellValue(produto.descricao),
            DoubleCellValue(produto.quantidade),
            TextCellValue(produto.unidade),
            DoubleCellValue(produto.valorUnitario),
            FormulaCellValue("=C${currentChildRow}*E${currentChildRow}"),
            FormulaCellValue("=F${currentChildRow}*0.2732"),
            FormulaCellValue("=G${currentChildRow}*0.205"),
          ]);
        }
        _adjustColumnWidths(childSheet);
      }
    }

    // ===== PLANILHA PRODUTOS RESTANTES (se for nota mãe) =====
    if (nota.cfop == "5922" && nota.produtosRestantes.isNotEmpty) {
      Sheet remainingSheet = excel["Produtos Restantes"]!; // Use ! para assumir que a sheet existe ou que será criada

      remainingSheet.appendRow([TextCellValue("Código"), TextCellValue("Descrição"), TextCellValue("Quantidade"), TextCellValue("Unidade")]);

      for (var produto in nota.produtosRestantes) {
        remainingSheet.appendRow([
          TextCellValue(produto.codigo.lstrip('0')),
          TextCellValue(produto.descricao),
          DoubleCellValue(produto.quantidade),
          TextCellValue(produto.unidade),
        ]);
      }
      _adjustColumnWidths(remainingSheet);
    }

    // O método encode() do pacote excel retorna Uint8List?. Adicionamos ! para garantir que não é nulo.
    return excel.encode()!;
  }

  static void _adjustColumnWidths(Sheet sheet) {
    for (int colIndex = 0; colIndex < sheet.maxColumns; colIndex++) {
      double maxLen = 0;
      for (int rowIndex = 0; rowIndex < sheet.maxRows; rowIndex++) {
        // Usa CellIndex.indexByColumnRow para criar o CellIndex
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
        final cellValue = cell.value?.toString() ?? '';
        if (cellValue.length > maxLen) {
          maxLen = cellValue.length.toDouble();
        }
      }
      sheet.setColumnAutoFit(colIndex); // Tenta autofit, pode ser mais robusto
      // Ou define manualmente com base em maxLen se autoFit não for suficiente
      // sheet.setColumnWidth(colIndex, (maxLen + 2) * 1.2); // Ajuste um fator se necessário
    }
  }
}