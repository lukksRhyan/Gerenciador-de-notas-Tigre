import 'dart:io';
import 'package:notas_tigre/models/nota.dart';
import 'package:notas_tigre/utils/icms_calculator.dart';

// lib/utils/automation_helper.dart

class AutomacaoSistema {
  // Flag para controle externo de interrupção
  static bool cancelarLote = false;

  static Future<void> executarLancamento(Produto produto) async {
    final icms = IcmsCalculator.calculateBaseICMS(produto.quantidade * produto.valorUnitario);
    
    final codigo = produto.codigo.replaceAll(RegExp(r'^0+'), '');
    final qtd = produto.quantidade.toString();
    final vlrUnit = produto.valorUnitario.toStringAsFixed(4);
    final baseCalc = icms['base'].toStringAsFixed(2);
    final valorIcms = icms['ICMS'].toStringAsFixed(2);

    try {
      final scriptPath = '${Directory.current.path}/lib/utils/automacao.py';
      
      final result = await Process.run('python', [
        scriptPath,
        codigo,
        qtd,
        vlrUnit,
        baseCalc,
        valorIcms
      ]);

      if (result.stderr.toString().isNotEmpty) {
        print("Erro Python: ${result.stderr}");
      }
    } catch (e) {
      print("Erro crítico ao chamar o processo: $e");
    }
  }

  // Novo método para execução em lote
  static Future<void> executarLote(
    List<Produto> produtos, 
    Function(int) onProgress, 
    Function(String) onStatus
  ) async {
    cancelarLote = false;
    
    for (int i = 0; i < produtos.length; i++) {
      if (cancelarLote) {
        onStatus("Automação interrompida pelo usuário.");
        break;
      }

      onStatus("Lançando produto ${i + 1} de ${produtos.length}...");
      onProgress(i + 1);
      
      await executarLancamento(produtos[i]);

      // Delay de 4 segundos entre produtos, exceto no último
      if (i < produtos.length - 1 && !cancelarLote) {
        for (int s = 4; s > 0; s--) {
          if (cancelarLote) break;
          onStatus("Aguardando delay de segurança... ($s segundos)");
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    
    if (!cancelarLote) onStatus("Lote concluído com sucesso!");
  }
}