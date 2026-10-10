import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/prestamo_model.dart';
import '../providers/prestamo_provider.dart';
import '../utils/formatters.dart';

class CrearPrestamoScreen extends StatefulWidget {
  const CrearPrestamoScreen({super.key});

  @override
  State<CrearPrestamoScreen> createState() => _CrearPrestamoScreenState();
}

class _CrearPrestamoScreenState extends State<CrearPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _prestadoController = TextEditingController();
  final _devolverController = TextEditingController();
  final _cuotasController = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Nuevo Préstamo', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _nombreController,
                label: 'Nombre del Cliente',
                icon: Icons.person_outline,
                validator: (val) => val == null || val.isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _prestadoController,
                label: 'Monto Prestado (₲)',
                icon: Icons.money,
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Ingresa el monto prestado' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _devolverController,
                label: 'Monto Total a Devolver (₲)',
                icon: Icons.trending_up,
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Ingresa el monto a devolver' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _cuotasController,
                label: 'Número de Cuotas',
                icon: Icons.format_list_numbered,
                keyboardType: TextInputType.number,
                validator: (val) => val == null || int.tryParse(val) == null || int.parse(val) <= 0
                    ? 'Ingresa un número válido'
                    : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _guardarPrestamo,
                child: Text(
                  'Guardar Préstamo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF0F766E)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
      ),
    );
  }

  void _guardarPrestamo() {
    if (_formKey.currentState!.validate()) {
      final double prestado = CurrencyFormatter.parse(_prestadoController.text);
      final double total = CurrencyFormatter.parse(_devolverController.text);
      final int numCuotas = int.parse(_cuotasController.text);

      double montoBaseCuota = total / numCuotas;
      List<CuotaModel> cuotas = [];

      for (int i = 1; i <= numCuotas; i++) {
        cuotas.add(CuotaModel(
          numero: i,
          montoOriginal: montoBaseCuota,
          montoPendiente: montoBaseCuota,
        ));
      }

      final nuevoPrestamo = PrestamoModel(
        id: const Uuid().v4(),
        clienteNombre: _nombreController.text.trim(),
        montoPrestado: prestado,
        montoTotal: total,
        fechaCreacion: DateTime.now(),
        cuotas: cuotas,
      );

      Provider.of<PrestamoProvider>(context, listen: false).agregarPrestamo(nuevoPrestamo);
      Navigator.pop(context);
    }
  }
}
