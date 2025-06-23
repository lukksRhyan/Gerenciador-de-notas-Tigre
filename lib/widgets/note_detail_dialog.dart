import 'package:flutter/material.dart';
import 'package:notas_tigre/models/nota.dart';
import 'package:intl/intl.dart';

class NoteDetailDialog extends StatelessWidget {
  final Nota nota;
  final Function(String) onExport;

  const NoteDetailDialog({super.key, required this.nota, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return AlertDialog(
      title: Text("Detalhes da Nota ${nota.numeroNota}"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow("Número da Nota:", nota.numeroNota),
            _buildDetailRow("CFOP:", nota.cfop),
            _buildDetailRow("Total:", currencyFormat.format(nota.total)),
            // Não temos data de criação no modelo Nota local, então removemos
            if (nota.informacoesAdicionais.isNotEmpty)
              _buildDetailRow("Informações Adicionais:", nota.informacoesAdicionais),
            if (nota.notaMaeNumero != null && nota.cfop != "5922") // Só mostra para notas filhas
              _buildDetailRow("Nota Mãe:", nota.notaMaeNumero!),
            const Divider(),
            const Text("Produtos:", style: TextStyle(fontWeight: FontWeight.bold)),
            if (nota.produtos.isNotEmpty)
              ...nota.produtos.map((produto) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("  • Código: ${produto.codigo.lstrip('0')} - ${produto.descricao}"),
                        Text("    Qtd: ${produto.quantidade} ${produto.unidade} | Valor Unitário: ${currencyFormat.format(produto.valorUnitario)}"),
                      ],
                    ),
                  )),
            if (nota.produtos.isEmpty)
              const Text("  Nenhum produto associado diretamente a esta nota."),

            // Exibir produtos restantes apenas se for nota mãe e tiver produtos restantes
            if (nota.cfop == "5922" && nota.produtosRestantes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text("Produtos Restantes (Nota Mãe):", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...nota.produtosRestantes.map((prod) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("  • Código: ${prod.codigo.lstrip('0')} - ${prod.descricao}"),
                        Text("    Qtd: ${prod.quantidade} ${prod.unidade}"),
                      ],
                    ),
                  )),
                ],
              ),

            // Exibir notas filhas apenas se for nota mãe
            if (nota.cfop == "5922" && nota.notasFilhas.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text("Notas Filhas:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...nota.notasFilhas.map((nf) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("  • Nota: ${nf.numeroNota} (CFOP: ${nf.cfop}) - Total: ${currencyFormat.format(nf.total)}"),
                        // Pode adicionar mais detalhes das notas filhas se necessário
                      ],
                    ),
                  )),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Fechar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onExport(nota.numeroNota);
          },
          icon: const Icon(Icons.download),
          label: const Text('Exportar Excel'),
        ),
        ElevatedButton(onPressed: (){

        }, child: const Text('Exportar dados...'))

      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 5),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}