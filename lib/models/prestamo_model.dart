class CuotaModel {
  final int numero;
  double montoOriginal;
  double montoPendiente;
  bool estaPagada;
  bool esParcial;

  CuotaModel({
    required this.numero,
    required this.montoOriginal,
    required this.montoPendiente,
    this.estaPagada = false,
    this.esParcial = false,
  });

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'montoOriginal': montoOriginal,
        'montoPendiente': montoPendiente,
        'estaPagada': estaPagada,
        'esParcial': esParcial,
      };

  factory CuotaModel.fromJson(Map<String, dynamic> json) => CuotaModel(
        numero: json['numero'],
        montoOriginal: json['montoOriginal'],
        montoPendiente: json['montoPendiente'],
        estaPagada: json['estaPagada'],
        esParcial: json['esParcial'] ?? false,
      );
}

class PrestamoModel {
  final String id;
  final String clienteNombre;
  final double montoPrestado;
  final double montoTotal;
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

  double get saldoPendiente {
    return cuotas.fold(0.0, (sum, c) => sum + c.montoPendiente);
  }

  bool get estaLiquidado {
    return cuotas.every((c) => c.estaPagada);
  }

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
        montoPrestado: json['montoPrestado'],
        montoTotal: json['montoTotal'],
        fechaCreacion: DateTime.parse(json['fechaCreacion']),
        cuotas: (json['cuotas'] as List)
            .map((c) => CuotaModel.fromJson(c))
            .toList(),
      );
}
