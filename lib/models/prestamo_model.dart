class CuotaModel {
  final int numero;
  double montoOriginal;
  double montoPendiente;
  bool estaPagada;

  CuotaModel({
    required this.numero,
    required this.montoOriginal,
    required this.montoPendiente,
    this.estaPagada = false,
  });

  /// Cuánto se pagó efectivamente en esta cuota.
  double get montoPagado => montoOriginal - montoPendiente;

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'montoOriginal': montoOriginal,
        'montoPendiente': montoPendiente,
        'estaPagada': estaPagada,
      };

  factory CuotaModel.fromJson(Map<String, dynamic> json) => CuotaModel(
        numero: json['numero'],
        montoOriginal: (json['montoOriginal'] as num).toDouble(),
        montoPendiente: (json['montoPendiente'] as num).toDouble(),
        estaPagada: json['estaPagada'] ?? false,
      );
}

class PrestamoModel {
  final String id;
  String clienteNombre;
  double montoPrestado;
  double montoTotal;
  final DateTime fechaCreacion;
  List<CuotaModel> cuotas;

  PrestamoModel({
    required this.id,
    required this.clienteNombre,
    required this.montoPrestado,
    required this.montoTotal,
    required this.fechaCreacion,
    required this.cuotas,
  });

  double get saldoPendiente =>
      cuotas.fold(0.0, (sum, c) => sum + c.montoPendiente);

  double get totalPagado =>
      cuotas.fold(0.0, (sum, c) => sum + c.montoPagado);

  bool get estaLiquidado => cuotas.every((c) => c.estaPagada);

  Map<String, dynamic> toJson() => {
        'id': id,
        'clienteNombre': clienteNombre,
        'montoPrestado': montoPrestado,
        'montoTotal': montoTotal,
        'fechaCreacion': fechaCreacion.toIso8601String(),
        'cuotas': cuotas.map((c) => c.toJson()).toList(),
      };

  factory PrestamoModel.fromJson(Map<String, dynamic> json) => PrestamoModel(
        id: json['id'],
        clienteNombre: json['clienteNombre'],
        montoPrestado: (json['montoPrestado'] as num).toDouble(),
        montoTotal: (json['montoTotal'] as num).toDouble(),
        fechaCreacion: DateTime.parse(json['fechaCreacion']),
        cuotas: (json['cuotas'] as List)
            .map((c) => CuotaModel.fromJson(c))
            .toList(),
      );
}