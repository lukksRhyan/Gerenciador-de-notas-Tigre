import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notas_tigre/models/nota.dart';
import 'package:notas_tigre/utils/automation_helper.dart';
import 'package:notas_tigre/utils/icms_calculator.dart';

class ChildNoteDetailDialog extends StatefulWidget {
  final Nota nota;

  const ChildNoteDetailDialog({super.key, required this.nota});

  @override
  State<ChildNoteDetailDialog> createState() => _ChildNoteDetailDialogState();
}

class _ChildNoteDetailDialogState extends State<ChildNoteDetailDialog> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  // Estados para o controle da automação em lote
  bool _estaRodandoLote = false;
  String _statusLote = "";
  int _progressoLote = 0;

  /// Inicia o processo de automação sequencial com delay de 4 segundos
  void _iniciarLancamentoLote() async {
    setState(() {
      _estaRodandoLote = true;
      _statusLote = "Iniciando lote...";
      _progressoLote = 0;
    });

    try {
      await AutomacaoSistema.executarLote(
        widget.nota.produtos,
        (progresso) {
          if (mounted) setState(() => _progressoLote = progresso);
        },
        (status) {
          if (mounted) setState(() => _statusLote = status);
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _estaRodandoLote = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              "Produtos da Nota Filha: ${widget.nota.numeroNota}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Botões de controle de automação
          if (!_estaRodandoLote)
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill, color: Colors.green),
              label: const Text("Lançar Tudo (Lote)"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50),
              onPressed: widget.nota.produtos.isEmpty ? null : _iniciarLancamentoLote,
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              label: const Text("INTERROMPER"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
              onPressed: () => AutomacaoSistema.cancelarLote = true, // Sinaliza interrupção
            ),
        ],
      ),
      content: SizedBox(
        width: 1200, // Largura aumentada para comportar todas as colunas
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Painel de status e progresso do lote
            if (_estaRodandoLote || _statusLote.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _estaRodandoLote ? Colors.blue.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_estaRodandoLote)
                          const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_statusLote, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Text("$_progressoLote / ${widget.nota.produtos.length}"),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: widget.nota.produtos.isEmpty ? 0 : _progressoLote / widget.nota.produtos.length,
                    ),
                  ],
                ),
              ),

            // Tabela Completa de Produtos
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 15,
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade900),
                    headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    columns: const [
                      DataColumn(label: Text('Código')),
                      DataColumn(label: Text('Descrição')),
                      DataColumn(label: Text('Qtd')),
                      DataColumn(label: Text('V. Unit')),
                      DataColumn(label: Text('Total')),
                      DataColumn(label: Text('Base ICMS')),
                      DataColumn(label: Text('ICMS')),
                      DataColumn(label: Text('Ação')),
                    ],
                    rows: widget.nota.produtos.map((produto) {
                      // Cálculos em tempo real para exibição
                      final double total = produto.quantidade * produto.valorUnitario;
                      final icmsData = IcmsCalculator.calculateBaseICMS(total);

                      return DataRow(cells: [
                        DataCell(Text(produto.codigo.replaceAll(RegExp(r'^0+'), ''))),
                        DataCell(SizedBox(width: 200, child: Text(produto.descricao, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(produto.quantidade.toString())),
                        DataCell(Text(_currencyFormat.format(produto.valorUnitario))),
                        DataCell(Text(_currencyFormat.format(total))),
                        DataCell(Text(_currencyFormat.format(icmsData['base']))),
                        DataCell(Text(_currencyFormat.format(icmsData['ICMS']))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.rocket_launch, color: Colors.blue),
                            tooltip: "Lançar este produto",
                            onPressed: _estaRodandoLote ? null : () => AutomacaoSistema.executarLancamento(produto),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _estaRodandoLote ? null : () => Navigator.of(context).pop(),
          child: const Text("Fechar"),
        ),
      ],
    );
  }
}