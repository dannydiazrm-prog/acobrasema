import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/prestamo_model.dart';
import '../providers/prestamo_provider.dart';
import '../utils/formatters.dart';
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

  Future<void> _exportarRespaldoWhatsApp(BuildContext context, PrestamoProvider provider) async {
    try {
      if (provider.prestamos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos para respaldar.')));
        return;
      }

      final data = provider.prestamos.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(data);

      final directory = await getApplicationDocumentsDirectory();
      final fechaStr = DateTime.now().toString().split('.')[0].replaceAll(':', '-');
      final file = File('${directory.path}/respaldo_acobrasema_$fechaStr.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: '📁 Respaldo de datos - ACobraSema');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar respaldo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PrestamoProvider>(context);
    final prestamos = provider.prestamos;
    final prestamosFiltrados = prestamos.where((p) => p.clienteNombre.toLowerCase().contains(_busqueda.toLowerCase())).toList();

    // KPIs calculados sobre deudores activos
    double totalActivoEnCalle = prestamos.fold(0.0, (sum, p) => sum + p.montoPrestado);
    double totalPorCobrarActivo = prestamos.fold(0.0, (sum, p) => sum + p.saldoPendiente);
    int totalClientesActivos = prestamos.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Image.asset('assets/images/acobrasema.png', height: 40, fit: BoxFit.contain),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF0F766E)),
            tooltip: 'Hacer Respaldo (WhatsApp)',
            onPressed: () => _exportarRespaldoWhatsApp(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarjetas de Resumen Financiero
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buildMetricCard('Activos en Calle', CurrencyFormatter.format(totalActivoEnCalle), const Color(0xFF0F766E), Icons.wallet)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Por Cobrar', CurrencyFormatter.format(totalPorCobrarActivo), const Color(0xFFD97706), Icons.pending_actions_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricCard('Deudores', '$totalClientesActivos', const Color(0xFF059669), Icons.people_outline)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Barra de Búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _busqueda = val),
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nombre...',
                hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F766E)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
              ),
            ),
          ),

          // Lista de Préstamos Activos
          Expanded(
            child: prestamosFiltrados.isEmpty
                ? Center(
                    child: Text('No hay préstamos registrados', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 16)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: prestamosFiltrados.length,
                    itemBuilder: (context, index) {
                      final p = prestamosFiltrados[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => DetallePrestamoScreen(prestamoId: p.id)),
                            );
                          },
                          onLongPress: () {
                            _mostrarOpcionesEdicionEliminacion(context, p);
                          },
                          title: Text(
                            p.clienteNombre,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Prestado: ${CurrencyFormatter.format(p.montoPrestado)}',
                                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                                ),
                                Text(
                                  'Debe: ${CurrencyFormatter.format(p.saldoPendiente)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD97706),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearPrestamoScreen()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nuevo Préstamo', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesEdicionEliminacion(BuildContext context, PrestamoModel prestamo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prestamo.clienteNombre,
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF0F766E)),
              title: Text('Ajustar / Editar Préstamo', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditarPrestamoScreen(prestamo: prestamo)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Eliminar Préstamo', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _confirmarEliminacion(context, prestamo.id, prestamo.clienteNombre);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminacion(BuildContext context, String id, String nombre) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Eliminar préstamo?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Estás a punto de eliminar el registro de $nombre. Esta acción no se puede deshacer.', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () {
              Provider.of<PrestamoProvider>(context, listen: false).eliminarPrestamo(id);
              Navigator.pop(context);
            },
            child: Text('Eliminar', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
