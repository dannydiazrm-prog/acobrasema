import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prestamo_model.dart';

class PrestamoProvider with ChangeNotifier {
  List<PrestamoModel> _prestamos = [];
  final String _storageKey = 'prestamos_data_v3';

  List<PrestamoModel> get prestamos => _prestamos;

  PrestamoProvider() {
    cargarPrestamos();
  }

  Future<void> cargarPrestamos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      _prestamos = decoded.map((e) => PrestamoModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_prestamos.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    notifyListeners();
  }

  Future<void> agregarPrestamo(PrestamoModel prestamo) async {
    _prestamos.insert(0, prestamo);
    await _guardar();
  }

  Future<void> actualizarPrestamo(String id, String nuevoNombre, double nuevoPrestado, double nuevoTotal, List<CuotaModel> nuevasCuotas) async {
    final index = _prestamos.indexWhere((p) => p.id == id);
    if (index != -1) {
      _prestamos[index].clienteNombre = nuevoNombre;
      _prestamos[index].montoPrestado = nuevoPrestado;
      _prestamos[index].montoTotal = nuevoTotal;
      _prestamos[index].cuotas = nuevasCuotas;
      await _guardar();
    }
  }

  Future<void> eliminarPrestamo(String id) async {
    _prestamos.removeWhere((p) => p.id == id);
    await _guardar();
  }

  // Retorna true si el préstamo se liquidó por completo con este abono
  Future<bool> registrarAbonoCuota(String prestamoId, int numeroCuota, double montoAbonado) async {
    final prestamoIndex = _prestamos.indexWhere((p) => p.id == prestamoId);
    if (prestamoIndex == -1) return false;

    final prestamo = _prestamos[prestamoIndex];
    final cuotaIndex = prestamo.cuotas.indexWhere((c) => c.numero == numeroCuota);
    if (cuotaIndex == -1) return false;

    final cuota = prestamo.cuotas[cuotaIndex];

    if (montoAbonado >= cuota.montoPendiente) {
      double excedente = montoAbonado - cuota.montoPendiente;
      cuota.montoPendiente = 0;
      cuota.estaPagada = true;
      cuota.esParcial = false;

      if (excedente > 0 && cuotaIndex + 1 < prestamo.cuotas.length) {
        await registrarAbonoCuota(prestamoId, prestamo.cuotas[cuotaIndex + 1].numero, excedente);
      }
    } else {
      cuota.montoPendiente -= montoAbonado;
      cuota.esParcial = true;
      double faltante = cuota.montoPendiente;

      if (cuotaIndex + 1 < prestamo.cuotas.length) {
        prestamo.cuotas[cuotaIndex + 1].montoOriginal += faltante;
        prestamo.cuotas[cuotaIndex + 1].montoPendiente += faltante;
      }
    }

    bool liquidado = prestamo.estaLiquidado;
    if (liquidado) {
      // Se borra automáticamente si ya no tiene saldo pendiente
      _prestamos.removeWhere((p) => p.id == prestamoId);
    }

    await _guardar();
    return liquidado;
  }
}
