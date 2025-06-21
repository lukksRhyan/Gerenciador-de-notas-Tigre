import 'package:flutter/material.dart';

class IcmsCalculatorDialog extends StatefulWidget {
  final Function(double) onCalculate;

  const IcmsCalculatorDialog({super.key, required this.onCalculate});

  @override
  State<IcmsCalculatorDialog> createState() => _IcmsCalculatorDialogState();
}

class _IcmsCalculatorDialogState extends State<IcmsCalculatorDialog> {
  final TextEditingController _valueController = TextEditingController();
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("🧮 Calcular ICMS"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Valor do Produto',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final String valueStr = _valueController.text.trim();
                if (valueStr.isEmpty) {
                  setState(() {
                    _result = 'Por favor, insira um valor.';
                  });
                  return;
                }
                try {
                  final double value = double.parse(valueStr.replaceAll(',', '.'));
                  await widget.onCalculate(value);
                  // O resultado será exibido na página principal
                  Navigator.of(context).pop(); // Fecha o diálogo
                } catch (e) {
                  setState(() {
                    _result = 'Valor inválido. Insira um número.';
                  });
                }
              },
              child: const Text('Calcular'),
            ),
            const SizedBox(height: 10),
            Text(_result, style: const TextStyle(color: Colors.red)),
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
      ],
    );
  }
}