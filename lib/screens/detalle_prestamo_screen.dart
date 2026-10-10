import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/prestamo_provider.dart';
import '../utils/formatters.dart';

class DetallePrestamoScreen extends StatelessWidget {
  final String prestamoId;

  const DetallePrestamoScreen({super.key, required this.prestamoId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrestamoProvider>(
      builder: (context, provider, child) {
        final prestamoList = provider.prestamos.where((p) => p.id == prestamoId);
        
        // Si el préstamo fue liquidado y eliminado, salimos de la pantalla de detalles automáticamente
        if (prestamoList.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final prestamo = prestamoList.first;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(prestamo.clienteNombre, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResumenItem('Total Devolver', CurrencyFormatter.format(prestamo.montoTotal)),
                    _buildResumenItem('Saldo Actual', CurrencyFormatter.format(prestamo.saldoPendiente), isAlert: prestamo.saldoPendiente > 0),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: prestamo.cuotas.length,
                  itemBuilder: (context, index) {
                    final cuota = prestamo.cuotas[index];
                    bool estaBloqueada = index > 0 && !prestamo.cuotas[index - 1].estaPagada;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cuota.estaPagada
                            ? const Color(0xFFECFDF5)
                            : estaBloqueada
                                ? const Color(0xFFF1F5F9)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cuota.estaPagada
                              ? const Color(0xFFA7F3D0)
                              : estaBloqueada
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: cuota.estaPagada
                              ? const Color(0xFF059669)
                              : estaBloqueada
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F766E),
                          child: Text(
                            '${cuota.numero}',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          'Cuota ${cuota.numero}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: estaBloqueada ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          cuota.estaPagada
                              ? 'Pagada Total'
                              : cuota.esParcial
                                  ? 'Pendiente: ${CurrencyFormatter.format(cuota.montoPendiente)} (Parcial)'
                                  : 'Monto: ${CurrencyFormatter.format(cuota.montoOriginal)}',
                          style: GoogleFonts.plusJakartaSans(
                            color: cuota.estaPagada ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: estaBloqueada
                            ? const Icon(Icons.lock, color: Color(0xFF94A3B8))
                            : cuota.estaPagada
                                ? const Icon(Icons.check_circle, color: Color(0xFF059669))
                                : IconButton(
                                    icon: const Icon(Icons.payment, color: Color(0xFF0F766E)),
                                    onPressed: () => _mostrarDialogoPago(context, prestamo.id, cuota.numero, cuota.montoPendiente),
                                  ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumenItem(String label, String valor, {bool isAlert = false}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isAlert ? const Color(0xFFD97706) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _mostrarDialogoPago(BuildContext context, String prestamoId, int numeroCuota, double pendienteMax) {
    final controller = TextEditingController(text: pendienteMax.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Registrar Abono - Cuota $numeroCuota', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Monto a abonar (₲)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            onPressed: () async {
              final monto = CurrencyFormatter.parse(controller.text);
              if (monto > 0) {
                Navigator.pop(context); // cerrar diálogo

                // Registrar abono y verificar si se liquidó completamente
                bool liquidado = await Provider.of<PrestamoProvider>(context, listen: false)
                    .registrarAbonoCuota(prestamoId, numeroCuota, monto);

                if (liquidado) {
                  // Mensaje profesional y limpio
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Préstamo totalmente pagado y finalizado.'),
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                }
              }
            },
            child: Text('Confirmar Pago', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
