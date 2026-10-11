import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prestamo_model.dart';

class PrestamoProvider with ChangeNotifier {
  static const _storageKey = 'prestamos_data_v4';
  static const _lastBackupKey = 'last_backup_date';
  static const _primerUsoKey = 'primer_uso_date';

  List<PrestamoModel> _prestamos = [];
  List<PrestamoModel> get prestamos => List.unmodifiable(_prestamos);

  PrestamoProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_primerUsoKey)) {
      await prefs.setString(_primerUsoKey, DateTime.now().toIso8601String());
    }
    await cargarPrestamos();
  }

  // ─────────────────────────────────────────────────────────
  // CARGA Y GUARDADO
  // ─────────────────────────────────────────────────────────

  Future<void> cargarPrestamos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      _prestamos = decoded.map((e) => PrestamoModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_prestamos.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────────────────

  Future<void> agregarPrestamo(PrestamoModel prestamo) async {
    _prestamos.insert(0, prestamo);
    await _guardar();
  }

  Future<void> eliminarPrestamo(String id) async {
    _prestamos.removeWhere((p) => p.id == id);
    await _guardar();
  }

  Future<void> actualizarPrestamo({
    required String id,
    required String clienteNombre,
    required double montoPrestado,
    required double montoTotal,
    required List<CuotaModel> cuotas,
  }) async {
    final index = _prestamos.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final original = _prestamos[index];
    _prestamos[index] = PrestamoModel(
      id: original.id,
      clienteNombre: clienteNombre,
      montoPrestado: montoPrestado,
      montoTotal: montoTotal,
      fechaCreacion: original.fechaCreacion,
      cuotas: cuotas,
    );
    await _guardar();
  }

  // ─────────────────────────────────────────────────────────
  // ABONOS
  // ─────────────────────────────────────────────────────────

  /// Registra un abono en la cuota indicada.
  /// Retorna true si el préstamo quedó totalmente pagado.
  Future<bool> registrarAbonoCuota(
    String prestamoId,
    int numeroCuota,
    double montoAbonado,
  ) async {
    final index = _prestamos.indexWhere((p) => p.id == prestamoId);
    if (index == -1) return false;

    final prestamo = _prestamos[index];
    final cuotaIdx = prestamo.cuotas.indexWhere((c) => c.numero == numeroCuota);
    if (cuotaIdx == -1) return false;

    final cuota = prestamo.cuotas[cuotaIdx];

    if (montoAbonado >= cuota.montoPendiente) {
      // Pago completo (o de más): cierra la cuota y arrastra el excedente.
      final excedente = montoAbonado - cuota.montoPendiente;
      cuota.montoPendiente = 0;
      cuota.estaPagada = true;

      if (excedente > 0 && cuotaIdx + 1 < prestamo.cuotas.length) {
        await registrarAbonoCuota(
          prestamoId,
          prestamo.cuotas[cuotaIdx + 1].numero,
          excedente,
        );
      }
    } else {
      // Pago parcial: registrar lo efectivamente pagado y arrastrar el faltante.
      final faltante = cuota.montoPendiente - montoAbonado;
      cuota.montoOriginal = montoAbonado;
      cuota.montoPendiente = 0;
      cuota.estaPagada = true;

      if (cuotaIdx + 1 < prestamo.cuotas.length) {
        prestamo.cuotas[cuotaIdx + 1].montoOriginal += faltante;
        prestamo.cuotas[cuotaIdx + 1].montoPendiente += faltante;
      }
    }

    final liquidado = prestamo.estaLiquidado;
    if (liquidado) {
      _prestamos.removeWhere((p) => p.id == prestamoId);
    }

    await _guardar();
    return liquidado;
  }

  // ─────────────────────────────────────────────────────────
  // RESPALDO
  // ─────────────────────────────────────────────────────────

  String exportarDatos() {
    return jsonEncode(_prestamos.map((e) => e.toJson()).toList());
  }

  Future<bool> importarDatos(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return false;
      _prestamos = decoded.map((e) => PrestamoModel.fromJson(e)).toList();
      await _guardar();
      await marcarRespaldoHecho();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> marcarRespaldoHecho() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());
    notifyListeners();
  }

  Future<bool> necesitaRespaldo() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastBackupKey) ?? prefs.getString(_primerUsoKey);
    if (last == null) return false;
    final lastDate = DateTime.parse(last);
    return DateTime.now().difference(lastDate).inDays >= 7;
  }

  Future<DateTime?> ultimaFechaRespaldo() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastBackupKey);
    if (last == null) return null;
    return DateTime.parse(last);
  }
}