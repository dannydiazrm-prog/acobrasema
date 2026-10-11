import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/prestamo_model.dart';
import '../providers/prestamo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/formatters.dart';

class CrearPrestamoScreen extends StatefulWidget {
  const CrearPrestamoScreen({super.key});

  @override
  State<CrearPrestamoScreen> createState() => _CrearPrestamoScreenState();
}

class _CrearPrestamoScreenState extends State<CrearPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _prestadoCtrl = TextEditingController();
  final _devolverCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController(text: '1');

  List<double> _montosCuotas = [];

  /// Índices de cuotas que el usuario editó manualmente.
  /// Esas cuotas quedan fijas y no se tocan al redistribuir.
  final Set<int> _cuotasEditadas = {};

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _prestadoCtrl.dispose();
    _devolverCtrl.dispose();
    _cuotasCtrl.dispose();
    super.dispose();
  }

  void _recalcularCuotasAuto() {
    final total = CurrencyFormatter.parse(_devolverCtrl.text);
    final n = int.tryParse(_cuotasCtrl.text) ?? 0;
    if (total <= 0 || n <= 0) {
      setState(() => _montosCuotas = []);
      return;
    }
    final base = total / n;
    final montos = List.generate(n, (_) => base.floorToDouble());
    final suma = montos.fold(0.0, (s, v) => s + v);
    montos[n - 1] += total - suma;

    setState(() {
      _montosCuotas = montos;
      _cuotasEditadas.clear();
    });
  }

  /// Máximo que puede tener la cuota `index` considerando las demás
  /// cuotas ya fijadas (editadas manualmente).
  double _maximoParaCuota(int index) {
    final total = CurrencyFormatter.parse(_devolverCtrl.text);
    if (total <= 0) return 0;

    double sumaFijas = 0;
    for (int i = 0; i < _montosCuotas.length; i++) {
      if (i != index && _cuotasEditadas.contains(i)) {
        sumaFijas += _montosCuotas[i];
      }
    }
    return (total - sumaFijas).clamp(0, total);
  }

  /// Edita una cuota manualmente, redistribuyendo solo entre las no editadas.
  void _editarCuotaManual(int index, double nuevoMonto) {
    final total = CurrencyFormatter.parse(_devolverCtrl.text);
    if (total <= 0) return;

    final maximo = _maximoParaCuota(index);
    if (nuevoMonto > maximo) nuevoMonto = maximo;
    if (nuevoMonto < 0) return;

    final nuevos = List<double>.from(_montosCuotas);
    nuevos[index] = nuevoMonto;
    _cuotasEditadas.add(index);

    // Cuotas que todavía no fueron editadas (excluyendo la actual).
    final noEditadas = <int>[];
    for (int i = 0; i < nuevos.length; i++) {
      if (i != index && !_cuotasEditadas.contains(i)) {
        noEditadas.add(i);
      }
    }

    // Cuánto queda por repartir después de fijar las editadas.
    double sumaFijas = 0;
    for (int i = 0; i < nuevos.length; i++) {
      if (_cuotasEditadas.contains(i)) sumaFijas += nuevos[i];
    }
    final restante = total - sumaFijas;

    if (noEditadas.isEmpty) {
      // No hay más cuotas libres: solo actualizamos el valor.
      setState(() => _montosCuotas = nuevos);
      return;
    }

    // Repartir el restante entre las no editadas.
    final montoPorOtra = restante / noEditadas.length;
    for (final i in noEditadas) {
      nuevos[i] = montoPorOtra.floorToDouble();
    }

    // Ajuste de redondeo: la última no editada absorbe la diferencia.
    final suma = nuevos.fold(0.0, (s, v) => s + v);
    final dif = total - suma;
    if (dif != 0) {
      nuevos[noEditadas.last] += dif;
    }

    setState(() => _montosCuotas = nuevos);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Filtrar cuotas con monto 0.
    final cuotasValidas = _montosCuotas.where((m) => m > 0).toList();

    if (cuotasValidas.isEmpty) {
      AppToast.error(context, 'El monto total debe ser mayor a cero');
      return;
    }

    final cuotas = List.generate(cuotasValidas.length, (i) {
      return CuotaModel(
        numero: i + 1,
        montoOriginal: cuotasValidas[i],
        montoPendiente: cuotasValidas[i],
      );
    });

    final nuevo = PrestamoModel(
      id: const Uuid().v4(),
      clienteNombre: _nombreCtrl.text.trim(),
      montoPrestado: CurrencyFormatter.parse(_prestadoCtrl.text),
      montoTotal: CurrencyFormatter.parse(_devolverCtrl.text),
      fechaCreacion: DateTime.now(),
      cuotas: cuotas,
    );

    await Provider.of<PrestamoProvider>(context, listen: false).agregarPrestamo(nuevo);
    if (!mounted) return;
    AppToast.success(context, 'Préstamo registrado');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nuevo Préstamo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos del cliente', style: AppText.subtitle),
                  const SizedBox(height: 16),
                  _textField(
                    controller: _nombreCtrl,
                    label: 'Nombre',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos del préstamo', style: AppText.subtitle),
                  const SizedBox(height: 16),
                  _moneyField(
                    controller: _prestadoCtrl,
                    label: 'Monto prestado',
                    icon: Icons.account_balance_wallet_outlined,
                    validator: (v) {
                      final n = CurrencyFormatter.parse(v ?? '');
                      return n <= 0 ? 'Ingresá un monto' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _moneyField(
                    controller: _devolverCtrl,
                    label: 'Monto a devolver',
                    icon: Icons.trending_up_rounded,
                    onChanged: (_) => _recalcularCuotasAuto(),
                    validator: (v) {
                      final n = CurrencyFormatter.parse(v ?? '');
                      final prestado = CurrencyFormatter.parse(_prestadoCtrl.text);
                      if (n <= 0) return 'Ingresá un monto';
                      if (n < prestado) return 'Debe ser ≥ al prestado';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _cuotasCtrl,
                    label: 'Número de cuotas',
                    icon: Icons.format_list_numbered_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _recalcularCuotasAuto(),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0) ? 'Ingresá al menos 1' : null;
                    },
                  ),
                ],
              ),
            ),
            if (_montosCuotas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Cuotas', style: AppText.subtitle),
                        const Spacer(),
                        if (_montosCuotas.length > 1)
                          Text(
                            'Tocá para ajustar',
                            style: AppText.caption.copyWith(color: AppColors.teal),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_montosCuotas.length, (i) => _cuotaEditable(i)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              child: const Text('Guardar Préstamo'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _cuotaEditable(int index) {
    final monto = _montosCuotas[index];
    final editada = _cuotasEditadas.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: editada ? AppColors.teal.withOpacity(0.06) : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: editada ? AppColors.teal.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: editada ? AppColors.teal : AppColors.navy,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: AppText.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              CurrencyFormatter.format(monto),
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (_montosCuotas.length > 1)
            TextButton(
              onPressed: () => _editarMontoCuota(index, monto),
              child: Text(
                'Editar',
                style: AppText.caption.copyWith(color: AppColors.teal),
              ),
            ),
        ],
      ),
    );
  }

  void _editarMontoCuota(int index, double actual) {
    final maximo = _maximoParaCuota(index);
    final ctrl = TextEditingController(
      text: CurrencyFormatter.formatNumber(actual),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          final montoActual = CurrencyFormatter.parse(ctrl.text);
          final excede = montoActual > maximo;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            title: Text('Cuota ${index + 1}', style: AppText.title.copyWith(fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Máximo: ${CurrencyFormatter.format(maximo)}',
                  style: AppText.caption.copyWith(color: AppColors.textSecondary),
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
                    setDialogState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    suffixText: '₲',
                    errorText: excede ? 'Supera el máximo permitido' : null,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: excede || montoActual <= 0
                    ? null
                    : () {
                        _editarCuotaManual(index, montoActual);
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
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
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
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
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
      onChanged: (v) {
        final formatted = CurrencyFormatter.formatInput(v);
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        onChanged?.call(formatted);
      },
      style: AppText.body,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixText: '₲',
        suffixStyle: AppText.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}