import 'package:flutter/material.dart';
import 'package:notas_tigre/common/app_colors.dart';
import 'package:notas_tigre/common/styles/app_styles.dart';
import 'package:notas_tigre/models/nota.dart';
import 'package:notas_tigre/utils/pdf_parser.dart';
import 'package:notas_tigre/widgets/credit_footer.dart';
import 'package:notas_tigre/widgets/icms_calculator_dialog.dart';
import 'package:notas_tigre/widgets/note_detail_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:notas_tigre/widgets/pdf_input_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:notas_tigre/utils/xml_parser.dart';
import 'package:notas_tigre/utils/excel_generator.dart';
import 'package:notas_tigre/utils/icms_calculator.dart';
import 'package:notas_tigre/utils/configs.dart';
import 'package:notas_tigre/widgets/product_value_input_dialog.dart'; // NOVO IMPORT
import 'package:notas_tigre/models/note_storage.dart';
import 'package:notas_tigre/widgets/xml_batch_import_dialog.dart';

enum ValueInputOption { zerado, manual, pdf } 

class GerenciadorNotasPage extends StatefulWidget {
  const GerenciadorNotasPage({super.key});

  @override
  State<GerenciadorNotasPage> createState() => _GerenciadorNotasPageState();
}

class _GerenciadorNotasPageState extends State<GerenciadorNotasPage> {
  final TextEditingController _noteNumberController = TextEditingController();
  final TextEditingController _accessKeyController = TextEditingController();
  List<Nota> _notes = [];
  bool _isLoading = false;
  String _message = '';
  bool _showCompletedNotes = true;
  bool _showIncompleteNotes = true;

  @override
  void initState() {
    super.initState();
    _loadNotesFromJson();
  }

  Future<void> _loadNotesFromJson() async {
    setState(() {
      _isLoading = true;
      _message = 'Carregando notas salvas...';
    });
    try {
      final notes = await NoteStorage.loadNotes();
      setState(() {
        _notes = notes;
        _message = notes.isEmpty ? 'Nenhuma nota salva encontrada.' : '';
      });
    } catch (e) {
      setState(() {
        _message = 'Erro ao carregar notas: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _listNotes() async {
    setState(() {
      _isLoading = true;
      _message = 'Listando notas carregadas...';
    });
    if (_notes.isEmpty) {
      _message = 'Nenhuma nota carregada ainda. Adicione uma nota.';
    } else {
      _message = '';
    }
    setState(() {
      _isLoading = false;
    });
  }

 Future<ValueInputOption?> _showValueInputOptionDialog() async {
    return await showDialog<ValueInputOption>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Valores Unitários dos Produtos"),
          content: const Text("Como você deseja definir os valores unitários dos produtos da Nota Mãe?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Deixar Zerado"),
              onPressed: () => Navigator.of(context).pop(ValueInputOption.zerado),
            ),
            TextButton(
              child: const Text("Inserir Manualmente"),
              onPressed: () => Navigator.of(context).pop(ValueInputOption.manual),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(ValueInputOption.pdf), // <<< 3. Opção PDF no diálogo
              child: const Text("PDF do Pedido"),
            ),
          ],
        );
      },
    );
  }

 Future<void> _addNote() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xml'],
  );

  if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      setState(() {
        _isLoading = true;
        _message = 'Lendo arquivo XML...';
      });

      try {
        final xmlContent = await file.readAsString();
        final Map<String, dynamic> rawNoteData = XmlParser.extractNoteData(xmlContent);

        final String cfop = rawNoteData['CFOP'] as String? ?? '';
        if (cfop.isEmpty) {
          throw Exception('CFOP não encontrado no arquivo XML.');
        }

        List<Produto> productsWithValues = (rawNoteData['Produtos'] as List)
            .map((p) => Produto.fromJson(p)).toList();

        if (cfop == "5922") { // Se for Nota Mãe, pede a opção de preenchimento
          final option = await _showValueInputOptionDialog(); // <<< 4. Chama o diálogo de três opções

          if (option == ValueInputOption.manual) {
            // ... (Lógica de Inserção Manual inalterada)
          } else if (option == ValueInputOption.pdf) { // <<< 5. LÓGICA DE PARSING DE PDF
            Map<String, double> priceMap = {};
            
            await showDialog( // <<< 6. Abre o Diálogo de Entrada de Texto/Arquivo PDF
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return PdfInputDialog(
                  onExtract: (pdfText) {
                    // Chama o parser para extrair o mapa de preços do texto
                    priceMap = PdfParser.extractValuesFromText(pdfText); 
                  },
                );
              },
            );

            // Aplica os valores extraídos do PDF
            for (int i = 0; i < productsWithValues.length; i++) {
              final String code = productsWithValues[i].codigo.lstripAllZeros();
              if (priceMap.containsKey(code)) {
                productsWithValues[i] = productsWithValues[i].copyWith(
                  valorUnitario: priceMap[code]!,
                );
              } else {
                debugPrint('Produto $code da NF não encontrado no PDF do Pedido.');
              }
            }
            setState(() {
              _message = 'Valores unitários preenchidos via PDF/Texto. Verifique a lista de notas.';
            });
          }
        }

        final processedNota = XmlParser.addNotaToNotesList(rawNoteData, productsWithValues, _notes);

        setState(() {
          _message = 'Nota ${processedNota.numeroNota} processada e adicionada com sucesso!';
        });
        await NoteStorage.saveNotes(_notes); // Salva as notas
        _loadNotesFromJson(); // Recarrega para atualizar o estado e a lista
      } catch (e) {
        setState(() {
          _message = 'Erro ao processar o arquivo XML: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  } else {
    setState(() {
      _message = 'Nenhum arquivo XML selecionado.';
    });
  }
}

  Future<void> _consultNote() async {
    final String numeroNota = _noteNumberController.text.trim();
    if (numeroNota.isEmpty) {
      setState(() {
        _message = 'Por favor, digite um número de nota válido.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Consultando nota $numeroNota...';
    });
    try {
      final Nota nota = _notes.firstWhere(
        (n) => n.numeroNota == numeroNota,
        orElse: () => throw Exception('Nota $numeroNota não encontrada.'),
      );

      setState(() {
        _message = '';
      });
      _showNoteDetailsDialog(nota);
    } catch (e) {
      setState(() {
        _message = 'Erro ao consultar nota $numeroNota: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNoteDetailsDialog(Nota nota) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return NoteDetailDialog(
          nota: nota,
          onExport: (String noteNumber) async {
            await _exportExcel(noteNumber);
          },
        );
      },
    );
  }

  Future<void> _exportExcel(String numeroNota) async {
    setState(() {
      _isLoading = true;
      _message = 'Exportando Excel para nota $numeroNota...';
    });
    try {
      final Nota notaToExport = _notes.firstWhere(
        (n) => n.numeroNota == numeroNota,
        orElse: () => throw Exception('Nota $numeroNota não encontrada para exportação.'),
      );

      final excelBytes = await ExcelGenerator.generateExcelData(notaToExport);

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception("Não foi possível acessar o diretório de downloads.");
      }
      final filePath = '${directory.path}/nota_$numeroNota.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excelBytes);

      setState(() {
        _message = 'Arquivo Excel salvo em: $filePath';
      });
      await OpenFilex.open(filePath);
    } catch (e) {
      setState(() {
        _message = 'Erro ao exportar Excel: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showIcmsCalculatorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return IcmsCalculatorDialog(
          onCalculate: (double value) async {
            setState(() {
              _isLoading = true;
              _message = 'Calculando ICMS...';
            });
            try {
              final results = IcmsCalculator.calculateBaseICMS(value);

              setState(() {
                _message = 'Base de cálculo: R\$ ${results['base'].toStringAsFixed(2)} \nICMS Calculado: R\$ ${results['ICMS'].toStringAsFixed(2)}';
              });
            } catch (e) {
              setState(() {
                _message = 'Erro ao calcular ICMS: $e';
              });
            } finally {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
      },
    );
  }

  Future<void> _chooseNotesFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        MyAppConfigs().notesFolderPath = selectedDirectory;
        _message = 'Pasta de notas definida: $selectedDirectory';
      });
      await _loadNotesFromJson(); // Recarrega notas da nova pasta
    }
  }

  Future<void> _openXmlByAccessKey() async {
  final accessKey = _accessKeyController.text.trim();
  if (accessKey.isEmpty) {
    setState(() {
      _message = 'Digite a chave de acesso da nota.';
    });
    return;
  }
  final xmlFolder = MyAppConfigs().xmlFolderPath;
  if (xmlFolder.isEmpty) {
    setState(() {
      _message = 'Configure a pasta padrão dos XMLs nas configurações.';
    });
    return;
  }
  final xmlPath = '$xmlFolder/$accessKey.xml';
  final xmlFile = File(xmlPath);
  if (!await xmlFile.exists()) {
    setState(() {
      _message = 'Arquivo não encontrado: $xmlPath';
    });
    return;
  }
  try {
    final xmlContent = await xmlFile.readAsString();
    final rawNoteData = XmlParser.extractNoteData(xmlContent);
    final cfop = rawNoteData['CFOP'] as String? ?? '';
    if (cfop.isEmpty) throw Exception('CFOP não encontrado no XML.');
    List<Produto> productsWithValues = (rawNoteData['Produtos'] as List)
        .map((p) => Produto.fromJson(p)).toList();

    final processedNota = XmlParser.addNotaToNotesList(rawNoteData, productsWithValues, _notes);
    setState(() {
      _message = 'Nota ${processedNota.numeroNota} carregada pela chave de acesso!';
    });
    await NoteStorage.saveNotes(_notes);
    _listNotes();
  } catch (e) {
    setState(() {
      _message = 'Erro ao abrir XML: $e';
    });
  }
}

  Future<void> _showConfigDialog() async {
  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Configurações de Pastas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.folder),
              label: const Text('Selecionar pasta das notas'),
              onPressed: () async {
                String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                if (selectedDirectory != null) {
                  setState(() {
                    MyAppConfigs().notesFolderPath = selectedDirectory;
                    _message = 'Pasta de notas definida: $selectedDirectory';
                  });
                  await _loadNotesFromJson();
                }
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Selecionar pasta dos XMLs'),
              onPressed: () async {
                String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                if (selectedDirectory != null) {
                  setState(() {
                    MyAppConfigs().xmlFolderPath = selectedDirectory;
                    _message = 'Pasta de XMLs definida: $selectedDirectory';
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Fechar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

  Future<void> _importXmlBatch() async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return XmlBatchImportDialog(
        onImport: (cnpj, setStatus, setProgress) async {
          final xmlFolder = MyAppConfigs().xmlFolderPath;
          if (xmlFolder.isEmpty) {
            setStatus('Configure a pasta dos XMLs nas configurações.');
            return;
          }
          setStatus('Lendo pasta...');
          final dir = Directory(xmlFolder);
          final files = dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.xml'))
              .toList();

          // Filtra arquivos pelo CNPJ na chave de acesso (7º ao 20º caractere)
          List<File> filteredFiles = files;
          if (cnpj.isNotEmpty && cnpj.length == 14) {
            filteredFiles = files.where((file) {
              final fileName = file.uri.pathSegments.last.replaceAll('.xml', '');
              if (fileName.length >= 20) {
                final cnpjFromKey = fileName.substring(6, 20);
                return cnpjFromKey == cnpj;
              }
              return false;
            }).toList();
          }

          final total = filteredFiles.length;
          if (total == 0) {
            setStatus('Nenhum arquivo XML encontrado para o CNPJ informado.');
            return;
          }

          // Separar notas mãe e filhas
          List<Map<String, dynamic>> motherNotes = [];
          List<Map<String, dynamic>> childNotes = [];

          int processed = 0;
          for (final file in filteredFiles) {
            try {
              final xmlContent = await file.readAsString();
              final rawNoteData = XmlParser.extractNoteData(xmlContent);
              final cfop = rawNoteData['CFOP'] as String? ?? '';
              if (cfop == "5922") {
                motherNotes.add(rawNoteData);
              } else if (cfop == "5116") {
                childNotes.add(rawNoteData);
              }
              // Ignora outros CFOPs
            } catch (_) {
              // Ignora arquivos inválidos
            }
            processed++;
            setProgress(processed / total * 0.5);
            setStatus('Lendo pasta... ($processed/$total)');
          }

          setStatus('Adicionando notas mãe...');
          for (int i = 0; i < motherNotes.length; i++) {
            final raw = motherNotes[i];
            List<Produto> products = (raw['Produtos'] as List)
                .map((p) => Produto.fromJson(p)).toList();
            XmlParser.addNotaToNotesList(raw, products, _notes);
            setProgress(0.5 + (i + 1) / motherNotes.length * 0.25);
            setStatus('Adicionando notas mãe... (${i + 1}/${motherNotes.length})');
          }

          setStatus('Adicionando notas filhas...');
          for (int i = 0; i < childNotes.length; i++) {
            final raw = childNotes[i];
            List<Produto> products = (raw['Produtos'] as List)
                .map((p) => Produto.fromJson(p)).toList();
            XmlParser.addNotaToNotesList(raw, products, _notes);
            setProgress(0.75 + (i + 1) / childNotes.length * 0.25);
            setStatus('Adicionando notas filhas... (${i + 1}/${childNotes.length})');
          }

          setStatus('Concluído!');
          setProgress(1.0);
          await NoteStorage.saveNotes(_notes);
          setState(() {});
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    // Define a largura para a coluna de ações (Left Pane)
    const double actionPanelWidth = 300.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(" Gerenciador de Notas Tigre"),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png')
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigDialog,
            tooltip: 'Configurações',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column( // Coluna principal para empilhar o conteúdo principal (Row) e o Footer
          children: [
            Expanded( // A Row de conteúdo principal ocupa o espaço vertical disponível
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Alinha o conteúdo ao topo
                children: [
                  // --- LADO ESQUERDO: Ações e Inputs ---
                  SizedBox(
                    width: actionPanelWidth, // Largura fixa para a coluna de ações
                    child: SingleChildScrollView( // Permite rolagem se as ações transbordarem verticalmente
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 250,
                            child: ElevatedButton.icon(
                              onPressed: _listNotes,
                              icon: const Icon(Icons.folder_open),
                              label: const Text("Listar Notas Carregadas"),
                              style: AppStyles.AppElevatedButtonStyles,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 250,
                            child: ElevatedButton.icon(
                              onPressed: _addNote,
                              icon: const Icon(Icons.add_circle),
                              label: const Text("Adicionar Nota (XML)"),
                              style: AppStyles.AppElevatedButtonStyles,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 250,
                            child: ElevatedButton.icon(
                              onPressed: _importXmlBatch,
                              icon: const Icon(Icons.file_download),
                              label: const Text("Importar XMLs em lote"),
                              style: AppStyles.AppElevatedButtonStyles,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text("Digite o número da nota:"),
                          SizedBox(
                            width: 250,
                            child: TextField(
                              controller: _noteNumberController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                hintText: 'Número da Nota',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 250,
                            child: ElevatedButton.icon(
                              onPressed: _consultNote,
                              icon: const Icon(Icons.search),
                              label: const Text("Consultar Nota"),
                              style: AppStyles.AppElevatedButtonStyles,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 250,
                            child: ElevatedButton.icon(
                              onPressed: _showIcmsCalculatorDialog,
                              icon: const Icon(Icons.calculate),
                              label: const Text("Calcular ICMS"),
                              style: AppStyles.AppElevatedButtonStyles,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 250,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _accessKeyController,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                      ),
                                      hintText: 'Chave de acesso',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _openXmlByAccessKey,
                                  icon: const Icon(Icons.vpn_key),
                                  label: const Text("Abrir XML"),
                                  style: AppStyles.AppElevatedButtonStyles,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChoiceChip(
                                avatar: _showCompletedNotes
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : null,
                                label: Text(_showCompletedNotes
                                    ? "Exibir notas completas"
                                    : "Ocultar notas completas"),
                                selected: _showCompletedNotes,
                                onSelected: (selected) {
                                  setState(() {
                                    _showCompletedNotes = !_showCompletedNotes;
                                  });
                                },
                                selectedColor: Colors.blue.shade100,
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                avatar: _showIncompleteNotes
                                    ? const Icon(Icons.hourglass_empty, color: Colors.orange)
                                    : null,
                                label: Text(_showIncompleteNotes
                                    ? "Exibir incompletas"
                                    : "Ocultar incompletas"),
                                selected: _showIncompleteNotes,
                                onSelected: (selected) {
                                  setState(() {
                                    _showIncompleteNotes = !_showIncompleteNotes;
                                  });
                                },
                                selectedColor: Colors.orange.shade100,
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 20), // Separador

                  // --- LADO DIREITO: Lista de Notas ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Indicador de carregamento/Mensagem
                        if (_isLoading)
                          const Center(child: LinearProgressIndicator())
                        else if (_message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(_message, style: TextStyle(color: _message.contains('Erro') ? Colors.red : Colors.black87)),
                          ),

                        // Área da Lista
                        Expanded(
                          child: _notes.isEmpty && !_isLoading && _message.isEmpty
                              ? const Text("Adicione um arquivo XML para começar a gerenciar notas localmente.")
                              : ListView.builder(
                                  itemCount: _notes
                                      .where((note) =>
                                        // Filtra completas/incompletas conforme os chips
                                        (note.cfop != "5922") ||
                                        (_showCompletedNotes && note.completa && note.cfop == "5922") ||
                                        (_showIncompleteNotes && !note.completa && note.cfop == "5922")
                                      )
                                      .length,
                                  itemBuilder: (context, index) {
                                      final filteredNotes = _notes
                                          .where((note) =>
                                            (note.cfop != "5922") ||
                                            (_showCompletedNotes && note.completa && note.cfop == "5922") ||
                                            (_showIncompleteNotes && !note.completa && note.cfop == "5922")
                                          )
                                          .toList();
                                  final note = filteredNotes[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    child: ListTile(
                                      leading: const Icon(Icons.description, color: Colors.blue),
                                      title: Text('Nota: ${note.numeroNota}'),
                                      subtitle: Text(
                                        'CFOP: ${note.cfop} | Total: R\$${note.total.toStringAsFixed(2)}'
                                        '${note.cfop == "5922" ? (note.completa ? " | COMPLETA" : " | INCOMPLETA") : ""}'
                                      ),
                                      onTap: () {
                                        _showNoteDetailsDialog(note);
                                      },
                                    ),
                                  );
                                },
                              ),
                        ),
                      ],
                  ),
                ),
              ],
            ),
          ),
          
          // Footer (mantido na parte inferior, abrangendo a largura total)
          const SizedBox(height: 10),
          CreditFooter(),
        ],
      ),
    ));
  }
}