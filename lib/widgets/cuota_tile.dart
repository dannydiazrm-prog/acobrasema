import 'package:flutter/material.dart';
import '../models/prestamo_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class CuotaTile extends StatelessWidget {
  final CuotaModel cuota;
  final bool bloqueada;
  final VoidCallback? onTap;

  const CuotaTile({
    super.key,
    required this.cuota,
    required this.bloqueada,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pagada = cuota.estaPagada;
    final puedeTocar = !bloqueada && !pagada;

    return Opacity(
      opacity: bloqueada ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: puedeTocar ? onTap : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pagada
                ? AppColors.success.withOpacity(0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: pagada
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.border,
              width: pagada ? 1.2 : 1,
            ),
            boxShadow: bloqueada ? null : AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pagada
                      ? AppColors.success
                      : bloqueada
                          ? AppColors.textMuted
                          : AppColors.navy,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                alignment: Alignment.center,
                child: pagada
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                    : Text(
                        '${cuota.numero}',
                        style: AppText.subtitle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuota ${cuota.numero}',
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pagada
                          ? 'Pagada · ${CurrencyFormatter.format(cuota.montoOriginal)}'
                          : 'Monto: ${CurrencyFormatter.format(cuota.montoPendiente)}',
                      style: AppText.caption.copyWith(
                        color: pagada ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (puedeTocar)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    'Abonar',
                    style: AppText.caption.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}