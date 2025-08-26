import 'package:flutter/material.dart';

class XmlBatchImportDialog extends StatefulWidget {
  final Future<void> Function(String, Function(String), Function(double)) onImport;
  const XmlBatchImportDialog({super.key, required this.onImport});

  @override
  State<XmlBatchImportDialog> createState() => _XmlBatchImportDialogState();
}

class _XmlBatchImportDialogState extends State<XmlBatchImportDialog> {
  String _status = 'Pronto para iniciar importação.';
  double _progress = 0.0;
  bool _isRunning = false;
  bool _isDone = false;
  final TextEditingController _cnpjController = TextEditingController();

  void _startImport() async {
    setState(() {
      _isRunning = true;
      _status = 'Lendo pasta...';
      _progress = 0.0;
    });
    await widget.onImport(
      _cnpjController.text.trim(),
      (status) => setState(() => _status = status),
      (progress) => setState(() => _progress = progress),
    );
    setState(() {
      _isDone = true;
      _status = 'Concluído!';
      _progress = 1.0;
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importação em lote de XMLs'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Filtrar por CNPJ do fornecedor (opcional):'),
          TextField(
            controller: _cnpjController,
            decoration: const InputDecoration(
              hintText: 'Digite o CNPJ (apenas números)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            keyboardType: TextInputType.number,
            maxLength: 14,
          ),
          const SizedBox(height: 16),
          Text(_status),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
        ],
      ),
      actions: [
        if (!_isRunning && !_isDone)
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar Importação'),
            onPressed: _startImport,
          ),
        if (_isDone)
          TextButton(
            child: const Text('Fechar'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        if (_isRunning)
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
      ],
    );
  }
}