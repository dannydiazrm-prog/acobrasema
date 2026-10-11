import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prestamo_model.dart';
import '../providers/prestamo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_toast.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import '../widgets/kpi_card.dart';
import '../widgets/prestamo_card.dart';
import 'ajustes_screen.dart';
import 'crear_prestamo_screen.dart';
import 'detalle_prestamo_screen.dart';
import 'editar_prestamo_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _busqueda = '';
  bool _recordatorioMostrado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chequearRecordatorio());
  }

  Future<void> _chequearRecordatorio() async {
    final provider = Provider.of<PrestamoProvider>(context, listen: false);
    final necesita = await provider.necesitaRespaldo();
    if (!mounted || !necesita || _recordatorioMostrado) return;
    _recordatorioMostrado = true;
    _mostrarRecordatorio();
  }

  void _mostrarRecordatorio() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.backup_rounded, color: AppColors.teal, size: 36),
              ),
              const SizedBox(height: 16),
              Text('Respaldá tus datos', style: AppText.title.copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                'Pasó una semana desde el último respaldo. Si se rompe el celular, podés perder todo.',
                style: AppText.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Más tarde',
                        style: AppText.body.copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AjustesScreen()),
                        );
                      },
                      child: Text(
                        'Respaldar',
                        style: AppText.body.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PrestamoProvider>(context);
    final prestamos = provider.prestamos;
    final filtrados = prestamos
        .where((p) => p.clienteNombre.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList();

    final totalPrestado = prestamos.fold(0.0, (s, p) => s + p.montoPrestado);
    final totalPorCobrar = prestamos.fold(0.0, (s, p) => s + p.saldoPendiente);
    final totalCobrado = prestamos.fold(0.0, (s, p) => s + p.totalPagado);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 96,
        title: const SizedBox(
          height: 60,
          width: 220,
          child: Image(
            image: AssetImage('assets/images/acobrasema.png'),
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AjustesScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: KpiCard(
                    label: 'Prestado',
                    value: CurrencyFormatter.format(totalPrestado),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KpiCard(
                    label: 'Cobrado',
                    value: CurrencyFormatter.format(totalCobrado),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KpiCard(
                    label: 'A cobrar',
                    value: CurrencyFormatter.format(totalPorCobrar),
                    icon: Icons.schedule_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _busqueda = ''),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final p = filtrados[i];
                      return PrestamoCard(
                        prestamo: p,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetallePrestamoScreen(prestamoId: p.id),
                            ),
                          );
                        },
                        onLongPress: () => _mostrarOpciones(p),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearPrestamoScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nuevo Préstamo',
          style: AppText.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_rounded, size: 56, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            _busqueda.isEmpty ? 'Sin préstamos activos' : 'Sin resultados',
            style: AppText.subtitle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            _busqueda.isEmpty
                ? 'Tocá "Nuevo Préstamo" para empezar'
                : 'Probá con otro nombre',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  void _mostrarOpciones(PrestamoModel prestamo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(prestamo.clienteNombre, style: AppText.title.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              _opcion(
                icon: Icons.edit_outlined,
                label: 'Editar / Ajustar',
                color: AppColors.navy,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditarPrestamoScreen(prestamo: prestamo),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _opcion(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                color: AppColors.danger,
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await AppDialogs.confirm(
                    context,
                    title: '¿Eliminar préstamo?',
                    message:
                        'Se eliminará el registro de ${prestamo.clienteNombre}. Esta acción no se puede deshacer.',
                    confirmText: 'Eliminar',
                    icon: Icons.warning_amber_rounded,
                  );
                  if (ok && mounted) {
                    await Provider.of<PrestamoProvider>(context, listen: false)
                        .eliminarPrestamo(prestamo.id);
                    if (mounted) AppToast.info(context, 'Préstamo eliminado');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcion({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(label, style: AppText.body.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}