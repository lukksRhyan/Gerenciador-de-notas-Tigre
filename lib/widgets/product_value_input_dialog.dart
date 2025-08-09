import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ProductValueInputDialog extends StatefulWidget {
  final String productCode;
  final String productDescription;

  const ProductValueInputDialog({
    super.key,
    required this.productCode,
    required this.productDescription,
  });

  @override
  State<ProductValueInputDialog> createState() => _ProductValueInputDialogState();
}

class _ProductValueInputDialogState extends State<ProductValueInputDialog> {
  final TextEditingController _valueController = TextEditingController();
  String _errorMessage = '';
  final _formKey = GlobalKey<FormState>();
  // 1. Crie um FocusNode para controlar o foco
  final FocusNode _valueFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 2. Solicita o foco no campo de texto após a construção do frame inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_valueFocusNode);
    });
  }

  @override
  void dispose() {
    // 3. Libera os recursos do TextEditingController e do FocusNode
    _valueController.dispose();
    _valueFocusNode.dispose();
    super.dispose();
  }

  String _formatProductCode(String code) {
    return code.replaceAll(RegExp(r'^0+(?=.)'), '');
  }

  void _handleConfirm() {
    if (!_formKey.currentState!.validate()) return;

    final valueText = _valueController.text.replaceAll(',', '.');
    try {
      final value = double.parse(valueText);
      if (value < 0) {
        setState(() => _errorMessage = 'O valor não pode ser negativo.');
        return;
      }
      Navigator.of(context).pop(value);
    } catch (e) {
      setState(() => _errorMessage = 'Valor inválido. Use apenas números e vírgula.');
    }
  }

  String? _validateInput(String? value) {
    if (value == null || value.isEmpty) {
      return 'O valor não pode ser vazio.';
    }

    // Verifica se tem apenas uma vírgula
    final commaCount = value.split(',').length - 1;
    if (commaCount > 1) {
      return 'Use apenas uma vírgula decimal.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final formattedCode = _formatProductCode(widget.productCode);
    final numberFormat = NumberFormat.decimalPattern('pt_BR');

    return AlertDialog(
      title: const Text("Valor Unitário para Produto"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Código: $formattedCode"),
              Text("Descrição: ${widget.productDescription}"),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                // 4. Associe o FocusNode ao TextFormField
                focusNode: _valueFocusNode,
                decoration: InputDecoration(
                  labelText: 'Valor Unitário',
                  hintText: 'Ex: ${numberFormat.format(12.34)}',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\,?\d*$')),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    // Garante que apenas uma vírgula é permitida
                    final commaCount = newValue.text.split(',').length - 1;
                    if (commaCount > 1) return oldValue;
                    return newValue;
                  }),
                ],
                validator: _validateInput,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _errorMessage = ''),
                onFieldSubmitted: (_) => _handleConfirm(),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(0.0),
          child: const Text("Cancelar (Zerar Valor)"),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text("Confirmar"),
        ),
      ],
    );
  }
}