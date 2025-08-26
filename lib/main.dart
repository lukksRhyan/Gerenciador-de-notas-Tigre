import 'package:flutter/material.dart';
import 'package:notas_tigre/common/app_colors.dart';
import 'package:notas_tigre/common/styles/app_styles.dart';
import 'package:notas_tigre/models/nota.dart';
import 'package:notas_tigre/widgets/credit_footer.dart';
import 'package:notas_tigre/widgets/icms_calculator_dialog.dart';
import 'package:notas_tigre/widgets/note_detail_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:notas_tigre/utils/xml_parser.dart';
import 'package:notas_tigre/utils/excel_generator.dart';
import 'package:notas_tigre/utils/icms_calculator.dart';
import 'package:notas_tigre/utils/configs.dart';
import 'package:notas_tigre/widgets/product_value_input_dialog.dart'; // NOVO IMPORT
import 'package:notas_tigre/models/note_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerenciador de Notas Tigre',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const GerenciadorNotasPage(),
    );
  }
}

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
      // Extrai os dados brutos da nota do XML
      final Map<String, dynamic> rawNoteData = XmlParser.extractNoteData(xmlContent);

      // CORREÇÃO: Trata a possibilidade de o CFOP ser null de forma segura
      final String cfop = rawNoteData['CFOP'] as String? ?? '';

      // Se o CFOP for vazio, não prossegue
      if (cfop.isEmpty) {
        throw Exception('CFOP não encontrado no arquivo XML.');
      }

      // SE FOR NOTA MÃE (CFOP 5922), PERGUNTA SOBRE VALORES UNITÁRIOS
      List<Produto> productsWithValues = (rawNoteData['Produtos'] as List)
          .map((p) => Produto.fromJson(p)).toList(); // Converte para lista de Produtos

      if (cfop == "5922") {
        final bool? manualInput = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // Força o usuário a escolher uma opção
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Valores Unitários dos Produtos"),
              content: const Text("Deseja inserir os valores unitários dos produtos manualmente?"),
              actions: <Widget>[
                TextButton(
                  child: const Text("Deixar Zerado"),
                  onPressed: () {
                    Navigator.of(context).pop(false); // Retorna false para zerado
                  },
                ),
                TextButton(
                  child: const Text("Inserir Manualmente"),
                  onPressed: () {
                    Navigator.of(context).pop(true); // Retorna true para manual
                  },
                ),
              ],
            );
          },
        );

        if (manualInput == true) {
          // Se o usuário escolheu inserir manualmente, itera sobre os produtos
          for (int i = 0; i < productsWithValues.length; i++) {
            Produto product = productsWithValues[i];
            setState(() {
              _message = 'Inserindo valor para: ${product.descricao} (${product.codigo})...';
            });
            final double? value = await showDialog<double>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return ProductValueInputDialog(
                  productCode: product.codigo,
                  productDescription: product.descricao,
                );
              },
            );

            if (value != null) {
              productsWithValues[i] = product.copyWith(valorUnitario: value);
            } else {
              // Se o usuário cancelar, pode-se optar por manter o valor 0 ou parar
              productsWithValues[i] = product.copyWith(valorUnitario: 0.0);
            }
          }
        }
      }

      // Agora, use XmlParser para processar e adicionar a nota à lista em memória,
      // passando os produtos já com os valores unitários definidos.
      final processedNota = XmlParser.addNotaToNotesList(rawNoteData, productsWithValues, _notes);

      setState(() {
        _message = 'Nota ${processedNota.numeroNota} processada e adicionada com sucesso!';
      });
      await NoteStorage.saveNotes(_notes); // Salva as notas
      _listNotes();
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
      _showNoteDetailsDialog(nota!);
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

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : _message.isNotEmpty
                      ? Text(
                          _message,
                          style: TextStyle(
                            color: _message.contains('Erro') ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : Container(),
              const SizedBox(height: 10),
              Expanded(
                child: _notes.isEmpty && !_isLoading && _message.isEmpty
                    ? const Text("Adicione um arquivo XML para começar a gerenciar notas localmente.")
                    : ListView.builder(
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: const Icon(Icons.description, color: Colors.blue),
                              title: Text('Nota: ${note.numeroNota}'),
                              subtitle: Text('CFOP: ${note.cfop} | Total: R\$${note.total.toStringAsFixed(2)}'),
                              onTap: () {
                                _showNoteDetailsDialog(note);
                               },
                            ),
                          );
                        },
                      ),
              ),
              CreditFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
