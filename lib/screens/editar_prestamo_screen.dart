import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/prestamo_model.dart';
import '../providers/prestamo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/formatters.dart';

class EditarPrestamoScreen extends StatefulWidget {
  final PrestamoModel prestamo;
  const EditarPrestamoScreen({super.key, required this.prestamo});

  @override
  State<EditarPrestamoScreen> createState() => _EditarPrestamoScreenState();
}

class _EditarPrestamoScreenState extends State<EditarPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _prestadoCtrl;
  late TextEditingController _devolverCtrl;
  late TextEditingController _cuotasCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.prestamo.clienteNombre);
    _prestadoCtrl = TextEditingController(
      text: CurrencyFormatter.formatNumber(widget.prestamo.montoPrestado),
    );
    _devolverCtrl = TextEditingController(
      text: CurrencyFormatter.formatNumber(widget.prestamo.montoTotal),
    );
    _cuotasCtrl = TextEditingController(text: widget.prestamo.cuotas.length.toString());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _prestadoCtrl.dispose();
    _devolverCtrl.dispose();
    _cuotasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final nuevoPrestado = CurrencyFormatter.parse(_prestadoCtrl.text);
    final nuevoTotal = CurrencyFormatter.parse(_devolverCtrl.text);
    final cuotasOriginales = widget.prestamo.cuotas;

    // Cuotas ya pagadas (no se tocan).
    final pagadasCount = cuotasOriginales.where((c) => c.estaPagada).length;
    final pagadoHastaAhora = cuotasOriginales
        .where((c) => c.estaPagada)
        .fold(0.0, (s, c) => s + c.montoOriginal);

    // Nuevo número total de cuotas solicitado por el usuario.
    final nuevoNumCuotas = int.parse(_cuotasCtrl.text);
    final numCuotasPendientes = nuevoNumCuotas - pagadasCount;

    if (numCuotasPendientes < 0) {
      AppToast.error(context, 'No podés poner menos cuotas que las ya pagadas');
      return;
    }

    // Monto por repartir entre las cuotas pendientes.
    final porRepartir = nuevoTotal - pagadoHastaAhora;

    final List<CuotaModel> nuevasCuotas = [];

    // 1) Conservar las cuotas ya pagadas (con sus datos originales).
    for (int i = 0; i < pagadasCount; i++) {
      nuevasCuotas.add(cuotasOriginales[i]);
    }

    // 2) Regenerar las cuotas pendientes.
    if (numCuotasPendientes > 0 && porRepartir > 0) {
      final base = porRepartir / numCuotasPendientes;
      for (int i = 0; i < numCuotasPendientes; i++) {
        nuevasCuotas.add(CuotaModel(
          numero: pagadasCount + i + 1,
          montoOriginal: base.floorToDouble(),
          montoPendiente: base.floorToDouble(),
        ));
      }
      // Ajuste de redondeo: la última absorbe la diferencia.
      final suma = nuevasCuotas.fold(0.0, (s, c) => s + c.montoOriginal);
      final dif = nuevoTotal - suma;
      nuevasCuotas.last.montoOriginal += dif;
      nuevasCuotas.last.montoPendiente += dif;
    } else if (numCuotasPendientes > 0) {
      // Si no hay nada que repartir, dejar cuotas en 0.
      for (int i = 0; i < numCuotasPendientes; i++) {
        nuevasCuotas.add(CuotaModel(
          numero: pagadasCount + i + 1,
          montoOriginal: 0,
          montoPendiente: 0,
          estaPagada: true,
        ));
      }
    }

    await Provider.of<PrestamoProvider>(context, listen: false).actualizarPrestamo(
      id: widget.prestamo.id,
      clienteNombre: _nombreCtrl.text.trim(),
      montoPrestado: nuevoPrestado,
      montoTotal: nuevoTotal,
      cuotas: nuevasCuotas,
    );

    if (!mounted) return;
    AppToast.success(context, 'Préstamo actualizado');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Editar Préstamo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              child: Column(
                children: [
                  _textField(
                    controller: _nombreCtrl,
                    label: 'Nombre',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _moneyField(
                    controller: _prestadoCtrl,
                    label: 'Monto prestado',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 12),
                  _moneyField(
                    controller: _devolverCtrl,
                    label: 'Monto a devolver',
                    icon: Icons.trending_up_rounded,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _cuotasCtrl,
                    label: 'Total de cuotas',
                    icon: Icons.format_list_numbered_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Las cuotas ya pagadas no se modifican. Solo se reajustan las pendientes.',
                      style: AppText.caption.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: const Text('Guardar cambios'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
      style: AppText.body,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        final n = CurrencyFormatter.parse(v ?? '');
        return n <= 0 ? 'Ingresá un monto' : null;
      },
      onChanged: (v) {
        final formatted = CurrencyFormatter.formatInput(v);
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      },
      style: AppText.body,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixText: '₲',
      ),
    );
  }
}