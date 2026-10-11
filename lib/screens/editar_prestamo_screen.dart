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

  late List<CuotaModel> _cuotas;

  /// Monto pagado REAL, capturado al abrir la pantalla.
  /// No cambia aunque el usuario modifique el monto a devolver.
  late final double _montoPagado;

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

    // Capturamos el pagado real ANTES de tocar nada.
    _montoPagado = widget.prestamo.totalPagado;

    // Copia de las cuotas, con montos verificados.
    final cuotasOriginales = widget.prestamo.cuotas;
    final pagadas = cuotasOriginales.where((c) => c.estaPagada).toList();
    final pendientesOriginales =
        cuotasOriginales.where((c) => !c.estaPagada).toList();

    final pendienteReal = widget.prestamo.montoTotal - _montoPagado;
    final sumaPendientesActual = pendientesOriginales.fold(
      0.0,
      (s, c) => s + c.montoPendiente,
    );
    final desfase = (sumaPendientesActual - pendienteReal).abs();

    _cuotas = pagadas
        .map((c) => CuotaModel(
              numero: c.numero,
              montoOriginal: c.montoOriginal,
              montoPendiente: 0,
              estaPagada: true,
            ))
        .toList();

    if (desfase > 1) {
      // Regenerar pendientes para que sumen exacto.
      if (pendientesOriginales.isNotEmpty && pendienteReal > 0) {
        final base =
            (pendienteReal / pendientesOriginales.length).floorToDouble();
        double suma = 0;
        for (int i = 0; i < pendientesOriginales.length; i++) {
          final esUltima = i == pendientesOriginales.length - 1;
          final monto = esUltima ? pendienteReal - suma : base;
          _cuotas.add(CuotaModel(
            numero: _cuotas.length + 1,
            montoOriginal: monto,
            montoPendiente: monto,
          ));
          suma += monto;
        }
      }
    } else {
      // Respetar montos personalizados.
      for (final c in pendientesOriginales) {
        _cuotas.add(CuotaModel(
          numero: _cuotas.length + 1,
          montoOriginal: c.montoOriginal,
          montoPendiente: c.montoPendiente,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _prestadoCtrl.dispose();
    _devolverCtrl.dispose();
    super.dispose();
  }

  double get _prestadoActual => CurrencyFormatter.parse(_prestadoCtrl.text);
  double get _totalActual => CurrencyFormatter.parse(_devolverCtrl.text);

  double get _pendienteActual => _cuotas
      .where((c) => !c.estaPagada)
      .fold(0.0, (s, c) => s + c.montoPendiente);

  List<CuotaModel> get _pendientes =>
      _cuotas.where((c) => !c.estaPagada).toList();

  void _redistribuirPendientes() {
    final total = _totalActual;
    final pendientes = _pendientes;
    if (pendientes.isEmpty) return;

    // Usar SIEMPRE el pagado real capturado al inicio.
    final montoRedistribuir = total - _montoPagado;
    if (montoRedistribuir <= 0) return;

    final base = (montoRedistribuir / pendientes.length).floorToDouble();
    double suma = 0;
    for (int i = 0; i < pendientes.length; i++) {
      final esUltima = i == pendientes.length - 1;
      final monto = esUltima ? montoRedistribuir - suma : base;
      pendientes[i].montoOriginal = monto;
      pendientes[i].montoPendiente = monto;
      suma += monto;
    }
  }

  void _aplicarAgregarMonto({
    required double capitalAdicional,
    required double aDevolverAdicional,
    required int numCuotas,
  }) {
    setState(() {
      final nuevoPrestado = _prestadoActual + capitalAdicional;
      final nuevoTotal = _totalActual + aDevolverAdicional;

      _prestadoCtrl.text = CurrencyFormatter.formatNumber(nuevoPrestado);
      _devolverCtrl.text = CurrencyFormatter.formatNumber(nuevoTotal);

      for (int i = 0; i < numCuotas; i++) {
        _cuotas.add(CuotaModel(
          numero: _cuotas.length + 1,
          montoOriginal: 0,
          montoPendiente: 0,
        ));
      }

      _redistribuirPendientes();
    });
  }

  Future<void> _abrirAgregarMonto() async {
    final resultado = await showDialog<_AgregarMontoResult>(
      context: context,
      builder: (_) => _AgregarMontoDialog(
        prestadoActual: _prestadoActual,
        totalActual: _totalActual,
        montoPagado: _montoPagado,
        pendienteActual: _pendienteActual,
        cuotasPendientes: _pendientes.length,
      ),
    );

    if (resultado == null) return;
    _aplicarAgregarMonto(
      capitalAdicional: resultado.capital,
      aDevolverAdicional: resultado.aDevolver,
      numCuotas: resultado.numCuotas,
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final nuevoPrestado = _prestadoActual;
    final nuevoTotal = _totalActual;

    if (nuevoTotal < nuevoPrestado) {
      AppToast.error(context, 'El total a devolver debe ser ≥ al prestado');
      return;
    }

    if (nuevoTotal < _montoPagado) {
      AppToast.error(context, 'El total no puede ser menor a lo ya pagado');
      return;
    }

    final cuotasFinales = <CuotaModel>[];
    int num = 1;
    for (final c in _cuotas) {
      if (c.estaPagada || c.montoPendiente > 0) {
        cuotasFinales.add(CuotaModel(
          numero: num++,
          montoOriginal: c.montoOriginal,
          montoPendiente: c.montoPendiente,
          estaPagada: c.estaPagada,
        ));
      }
    }

    if (cuotasFinales.isEmpty) {
      AppToast.error(context, 'No hay cuotas pendientes');
      return;
    }

    await Provider.of<PrestamoProvider>(context, listen: false)
        .actualizarPrestamo(
      id: widget.prestamo.id,
      clienteNombre: _nombreCtrl.text.trim(),
      montoPrestado: nuevoPrestado,
      montoTotal: nuevoTotal,
      cuotas: cuotasFinales,
    );

    if (!mounted) return;
    AppToast.success(context, 'Préstamo actualizado');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tienePagos = _montoPagado > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Editar Préstamo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (tienePagos) _resumenBox(),
            if (tienePagos) const SizedBox(height: 12),
            _botonAgregarMonto(),
            const SizedBox(height: 12),
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
                    onChanged: () {
                      setState(() => _redistribuirPendientes());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cuotas', style: AppText.subtitle),
                  const SizedBox(height: 12),
                  ..._cuotas.map((c) => _cuotaInfo(c)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (tienePagos) _avisoCuotasPagadas(),
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

  Widget _resumenBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.04),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.navy.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          _filaResumen('Total a devolver', CurrencyFormatter.format(_totalActual)),
          const SizedBox(height: 8),
          _filaResumen('Ya pagado', CurrencyFormatter.format(_montoPagado),
              color: AppColors.success),
          const SizedBox(height: 8),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          _filaResumen('Pendiente', CurrencyFormatter.format(_pendienteActual),
              color: AppColors.warning, bold: true),
        ],
      ),
    );
  }

  Widget _filaResumen(String label, String value,
      {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.caption),
        Text(
          value,
          style: AppText.body.copyWith(
            color: color ?? AppColors.textPrimary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _botonAgregarMonto() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: _abrirAgregarMonto,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Agregar monto al préstamo',
                  style: AppText.body.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avisoCuotasPagadas() {
    return Container(
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
    );
  }

  Widget _cuotaInfo(CuotaModel c) {
    final pagada = c.estaPagada;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: pagada
            ? AppColors.success.withOpacity(0.06)
            : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: pagada ? AppColors.success.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: pagada ? AppColors.success : AppColors.navy,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            alignment: Alignment.center,
            child: pagada
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '${c.numero}',
                    style: AppText.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cuota ${c.numero}',
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            CurrencyFormatter.format(pagada ? c.montoOriginal : c.montoPendiente),
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w800,
              color: pagada ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
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
  }) {
    return TextFormField(
      controller: controller,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
    VoidCallback? onChanged,
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
        onChanged?.call();
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

class _AgregarMontoResult {
  final double capital;
  final double aDevolver;
  final int numCuotas;

  _AgregarMontoResult({
    required this.capital,
    required this.aDevolver,
    required this.numCuotas,
  });
}

class _AgregarMontoDialog extends StatefulWidget {
  final double prestadoActual;
  final double totalActual;
  final double montoPagado;
  final double pendienteActual;
  final int cuotasPendientes;

  const _AgregarMontoDialog({
    required this.prestadoActual,
    required this.totalActual,
    required this.montoPagado,
    required this.pendienteActual,
    required this.cuotasPendientes,
  });

  @override
  State<_AgregarMontoDialog> createState() => _AgregarMontoDialogState();
}

class _AgregarMontoDialogState extends State<_AgregarMontoDialog> {
  final _capitalCtrl = TextEditingController();
  final _aDevolverCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _capitalCtrl.dispose();
    _aDevolverCtrl.dispose();
    _cuotasCtrl.dispose();
    super.dispose();
  }

  double get _capital => CurrencyFormatter.parse(_capitalCtrl.text);
  double get _aDevolver => CurrencyFormatter.parse(_aDevolverCtrl.text);
  int get _cuotas => int.tryParse(_cuotasCtrl.text) ?? 0;

  double get _nuevoPrestado => widget.prestadoActual + _capital;
  double get _nuevoTotal => widget.totalActual + _aDevolver;
  double get _nuevoPendiente => _nuevoTotal - widget.montoPagado;

  int get _cuotasFinales => widget.cuotasPendientes + _cuotas;

  double get _montoPorCuota {
    if (_cuotasFinales == 0) return 0;
    return _nuevoPendiente / _cuotasFinales;
  }

  bool get _valido =>
      _aDevolver > 0 &&
      _aDevolver >= _capital &&
      _cuotas >= 0 &&
      _cuotas <= 99;

  void _aplicar() {
    if (!_valido) return;
    Navigator.pop(
      context,
      _AgregarMontoResult(
        capital: _capital,
        aDevolver: _aDevolver,
        numCuotas: _cuotas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      title: Text(
        'Agregar monto al préstamo',
        style: AppText.title.copyWith(fontSize: 18),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _campoMonto(
              controller: _capitalCtrl,
              label: 'Capital adicional',
            ),
            const SizedBox(height: 12),
            _campoMonto(
              controller: _aDevolverCtrl,
              label: 'A devolver adicional',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cuotasCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: AppText.body,
              decoration: const InputDecoration(
                labelText: 'Nuevas cuotas (0 = mismo plazo)',
                helperText: 'Se redistribuye todo entre las cuotas pendientes',
                helperStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                prefixIcon: Icon(
                  Icons.format_list_numbered_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _filaResumen('Nuevo prestado', CurrencyFormatter.format(_nuevoPrestado)),
                  const SizedBox(height: 6),
                  _filaResumen('Nuevo a devolver', CurrencyFormatter.format(_nuevoTotal)),
                  const SizedBox(height: 6),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 6),
                  _filaResumen(
                    'Nuevo pendiente',
                    CurrencyFormatter.format(_nuevoPendiente),
                    color: AppColors.warning,
                    bold: true,
                  ),
                  if (_nuevoPendiente > 0 && _cuotasFinales > 0) ...[
                    const SizedBox(height: 8),
                    Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 8),
                    _filaResumen(
                      '$_cuotasFinales cuotas de',
                      CurrencyFormatter.format(_montoPorCuota),
                      color: AppColors.teal,
                      bold: true,
                    ),
                  ],
                ],
              ),
            ),
            if (_aDevolver > 0 && _aDevolver < _capital)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'El monto a devolver debe ser ≥ al capital',
                  style: AppText.caption.copyWith(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _valido ? _aplicar : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _valido ? AppColors.teal : AppColors.textMuted,
          ),
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  Widget _filaResumen(String label, String value,
      {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppText.caption)),
        Text(
          value,
          style: AppText.body.copyWith(
            color: color ?? AppColors.textPrimary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _campoMonto({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        final formatted = CurrencyFormatter.formatInput(v);
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        setState(() {});
      },
      style: AppText.body,
      decoration: InputDecoration(
        labelText: label,
        suffixText: '₲',
      ),
    );
  }
}