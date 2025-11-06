import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p; // Para manipulação de caminhos/extensões

/// Diálogo para o usuário fornecer o conteúdo do pedido (via texto colado ou arquivo PDF/TXT).
class PdfInputDialog extends StatefulWidget {
  final Function(String pdfText) onExtract;

  const PdfInputDialog({super.key, required this.onExtract});

  @override
  State<PdfInputDialog> createState() => _PdfInputDialogState();
}

class _PdfInputDialogState extends State<PdfInputDialog> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  // Rastreia o nome do arquivo selecionado para exibir ao usuário
  String _selectedFileName = '';

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFileName = '';
      _textController.clear();
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        // Agora aceita tanto PDF quanto TXT
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'], 
        dialogTitle: 'Selecione o arquivo do Pedido (PDF ou TXT)',
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String extension = p.extension(file.path).toLowerCase();
        String? content;
        
        if (extension == '.txt') {
          // Arquivo TXT: Leitura segura como string
          content = await file.readAsString();
          setState(() {
            _selectedFileName = result.files.single.name;
            _textController.text = content!;
          });
          widget.onExtract(content!);
          if (mounted) Navigator.of(context).pop();
        } else if (extension == '.pdf') {
          // Arquivo PDF: Informa que a leitura automática é inviável e pede a cópia manual
          setState(() {
            _selectedFileName = result.files.single.name;
            _errorMessage = 
                'Arquivo PDF selecionado. A leitura automática não é suportada. '
                'Por favor, copie o texto da tabela do PDF e cole no campo acima para extrair.';
          });
        }
        
      } else {
        _errorMessage = "Nenhum arquivo selecionado.";
      }
    } catch (e) {
      // Catch genérico para qualquer falha de FilePicker ou leitura de TXT
      _errorMessage = 'Erro ao ler arquivo: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _extractFromPaste() {
    if (_textController.text.isEmpty) {
      setState(() {
        _errorMessage = "Cole o texto do PDF do pedido ou selecione um arquivo.";
      });
      return;
    }
    // Lógica para extrair do conteúdo do TextField
    widget.onExtract(_textController.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PDF do Pedido - Entrada'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            const Text(
              'Forneça o pedido copiando o texto do PDF no campo abaixo ou selecionando o arquivo.',
            ),
            const SizedBox(height: 15),
            
            // Exibe o nome do arquivo selecionado
            if (_selectedFileName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Arquivo Selecionado: $_selectedFileName', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),

            TextField(
              controller: _textController,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                labelText: 'Cole o texto (o conteúdo do arquivo TXT selecionado aparecerá aqui)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton.icon(
          icon: _isLoading ? const SizedBox(
            width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf), // Ícone de PDF
          onPressed: _isLoading ? null : _pickFile,
          label: const Text('Selecionar PDF/TXT'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          onPressed: _extractFromPaste,
          label: const Text('Extrair'),
        ),
      ],
    );
  }
}