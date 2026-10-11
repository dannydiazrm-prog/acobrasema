import 'package:flutter/material.dart';
import '../models/prestamo_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class PrestamoCard extends StatelessWidget {
  final PrestamoModel prestamo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PrestamoCard({
    super.key,
    required this.prestamo,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final saldo = prestamo.saldoPendiente;
    final total = prestamo.montoTotal;
    final progreso = total == 0 ? 0.0 : ((total - saldo) / total).clamp(0.0, 1.0);
    final inicial = prestamo.clienteNombre.isNotEmpty
        ? prestamo.clienteNombre[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    inicial,
                    style: AppText.subtitle.copyWith(
                      color: Colors.white,
                      fontSize: 20,
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
                        prestamo.clienteNombre,
                        style: AppText.subtitle.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prestado: ${CurrencyFormatter.format(prestamo.montoPrestado)}',
                        style: AppText.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Debe',
                      style: AppText.caption.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(saldo),
                      style: AppText.subtitle.copyWith(
                        fontSize: 14,
                        color: saldo > 0 ? AppColors.warning : AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}