import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/prestamo_model.dart';
import '../providers/prestamo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import '../widgets/cuota_tile.dart';

class DetallePrestamoScreen extends StatelessWidget {
  final String prestamoId;
  const DetallePrestamoScreen({super.key, required this.prestamoId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrestamoProvider>(
      builder: (context, provider, _) {
        final list = provider.prestamos.where((p) => p.id == prestamoId).toList();

        if (list.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Préstamo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
                    ),
                    const SizedBox(height: 20),
                    Text('Préstamo finalizado', style: AppText.title, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Este préstamo ya no está en tu lista.',
                      style: AppText.body.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Volver'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final p = list.first;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: Text(p.clienteNombre)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _resumen(p),
              const SizedBox(height: 16),
              Text('Cuotas', style: AppText.subtitle),
              const SizedBox(height: 12),
              ...List.generate(p.cuotas.length, (i) {
                final cuota = p.cuotas[i];
                final bloqueada = i > 0 && !p.cuotas[i - 1].estaPagada;
                return CuotaTile(
                  cuota: cuota,
                  bloqueada: bloqueada,
                  onTap: () => _abrirAbono(context, p, cuota),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _resumen(PrestamoModel p) {
    final pagado = p.totalPagado;
    final saldo = p.saldoPendiente;
    final total = p.montoTotal;
    final progreso = total == 0 ? 0.0 : (pagado / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo pendiente', style: AppText.caption.copyWith(color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(saldo),
            style: AppText.display.copyWith(color: Colors.white, fontSize: 28),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.tealLight),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _mini('Total', CurrencyFormatter.format(total), Colors.white)),
              Expanded(child: _mini('Pagado', CurrencyFormatter.format(pagado), AppColors.tealLight)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                'Creado el ${CurrencyFormatter.formatDate(p.fechaCreacion)}',
                style: AppText.caption.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.copyWith(color: Colors.white.withOpacity(0.6))),
        const SizedBox(height: 2),
        Text(value, style: AppText.subtitle.copyWith(color: color, fontSize: 15)),
      ],
    );
  }

  Future<void> _abrirAbono(BuildContext context, PrestamoModel p, CuotaModel cuota) async {
    final ctrl = TextEditingController(
      text: CurrencyFormatter.formatNumber(cuota.montoPendiente),
    );

    final monto = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
        title: Text('Abonar cuota ${cuota.numero}', style: AppText.title.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _filaInfo(
                    'Pendiente cuota',
                    CurrencyFormatter.format(cuota.montoPendiente),
                  ),
                  const SizedBox(height: 4),
                  _filaInfo(
                    'Saldo total del préstamo',
                    CurrencyFormatter.format(p.saldoPendiente),
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              onChanged: (v) {
                final formatted = CurrencyFormatter.formatInput(v);
                ctrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              },
              decoration: const InputDecoration(
                labelText: 'Monto a abonar',
                suffixText: '₲',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final monto = CurrencyFormatter.parse(ctrl.text);
              Navigator.pop(context, monto);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (monto == null || monto <= 0) return;
    if (!context.mounted) return;

    // Validación contra el saldo TOTAL del préstamo, no contra la cuota.
    if (monto > p.saldoPendiente) {
      AppToast.error(context, 'El monto supera el saldo pendiente del préstamo');
      return;
    }

    final resultado = await Provider.of<PrestamoProvider>(context, listen: false)
        .registrarAbonoCuota(p.id, cuota.numero, monto);

    if (!context.mounted) return;

    switch (resultado) {
      case PrestamoProvider.abonoLiquidado:
        await AppDialogs.prestamoTerminado(context, p.clienteNombre);
        if (context.mounted) Navigator.pop(context);
        break;
      case PrestamoProvider.abonoOk:
        AppToast.success(context, 'Abono registrado');
        break;
      case PrestamoProvider.abonoExcedePendiente:
        AppToast.error(context, 'El monto supera el saldo pendiente');
        break;
      default:
        AppToast.error(context, 'No se pudo registrar el abono');
    }
  }

  Widget _filaInfo(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.caption),
        Text(
          value,
          style: AppText.body.copyWith(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}