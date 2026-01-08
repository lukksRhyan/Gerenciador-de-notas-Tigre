import 'package:flutter/material.dart';
import 'package:notas_tigre/models/nota.dart';
import 'package:intl/intl.dart';
import 'package:notas_tigre/utils/icms_calculator.dart';

class ChildNoteDetailDialog extends StatelessWidget {
  final Nota nota;

  const ChildNoteDetailDialog({super.key, required this.nota});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return AlertDialog(
      title: Text("Produtos da Nota Filha ${nota.numeroNota}"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Descrição')),
                DataColumn(label: Text('Qtd')),
                DataColumn(label: Text('V. Unit')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Base ICMS')),
                DataColumn(label: Text('ICMS')),
              ],
              rows: nota.produtos.map((produto) {
                final total = produto.quantidade * produto.valorUnitario;
                final icmsData = IcmsCalculator.calculateBaseICMS(total);

                return DataRow(cells: [
                  DataCell(Text(produto.codigo.lstrip('0'))),
                  DataCell(Text(produto.descricao)),
                  DataCell(Text(produto.quantidade.toString())),
                  DataCell(Text(currencyFormat.format(produto.valorUnitario))),
                  DataCell(Text(currencyFormat.format(total))),
                  DataCell(Text(currencyFormat.format(icmsData['base']))),
                  DataCell(Text(currencyFormat.format(icmsData['ICMS']))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}