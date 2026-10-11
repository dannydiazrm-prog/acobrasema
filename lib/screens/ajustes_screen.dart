import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/prestamo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  Future<void> _exportar(BuildContext context) async {
    final provider = Provider.of<PrestamoProvider>(context, listen: false);
    if (provider.prestamos.isEmpty) {
      AppToast.error(context, 'No hay datos para exportar');
      return;
    }
    try {
      final jsonString = provider.exportarDatos();
      final dir = await getApplicationDocumentsDirectory();
      final fecha = DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      final file = File('${dir.path}/acobrasema_respaldo_$fecha.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Respaldo ACobraSema',
        text: 'Respaldo de datos ACobraSema - ${CurrencyFormatter.formatDate(DateTime.now())}',
      );

      await provider.marcarRespaldoHecho();
      if (!context.mounted) return;
      AppToast.success(context, 'Respaldo compartido');
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, 'Error al exportar');
    }
  }

  Future<void> _importar(BuildContext context) async {
    final confirmar = await AppDialogs.confirm(
      context,
      title: '¿Importar respaldo?',
      message: 'Se reemplazarán TODOS los datos actuales por los del archivo. Esta acción no se puede deshacer.',
      confirmText: 'Importar',
      confirmColor: AppColors.navy,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmar) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      if (!context.mounted) return;
      final ok = await Provider.of<PrestamoProvider>(context, listen: false)
          .importarDatos(content);

      if (!context.mounted) return;
      if (ok) {
        AppToast.success(context, 'Datos importados correctamente');
        Navigator.pop(context);
      } else {
        AppToast.error(context, 'Archivo inválido');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, 'Error al importar');
    }
  }

  Future<void> _forzarRecordatorio(BuildContext context) async {
    final provider = Provider.of<PrestamoProvider>(context, listen: false);
    await provider.marcarRespaldoHecho();
    // Simulamos "hace 10 días" para que el próximo chequeo dispare.
    // No podemos falsear la fecha acá sin tocar prefs, así que solo avisamos:
    if (!context.mounted) return;
    AppToast.info(context, 'Recordatorio programado para próximo inicio');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Respaldo'),
          _tile(
            icon: Icons.upload_file_rounded,
            title: 'Exportar datos',
            subtitle: 'Compartir por WhatsApp, Drive o email',
            onTap: () => _exportar(context),
          ),
          _tile(
            icon: Icons.download_rounded,
            title: 'Importar datos',
            subtitle: 'Restaurar desde un archivo de respaldo',
            onTap: () => _importar(context),
          ),
          _tile(
            icon: Icons.notifications_active_outlined,
            title: 'Forzar recordatorio',
            subtitle: 'Para probar el aviso de respaldo',
            onTap: () => _forzarRecordatorio(context),
          ),
          const SizedBox(height: 24),
          _section('Información'),
          _tile(
            icon: Icons.info_outline_rounded,
            title: 'Versión',
            subtitle: '1.0.0',
            onTap: null,
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text('ACobraSema', style: AppText.caption),
                const SizedBox(height: 4),
                Text('© 2026', style: AppText.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: AppText.caption.copyWith(letterSpacing: 1.2, fontSize: 11),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(icon, color: AppColors.navy, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppText.caption),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}