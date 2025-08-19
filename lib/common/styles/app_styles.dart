import 'package:flutter/material.dart';
import 'package:notas_tigre/common/app_colors.dart';

class AppStyles{
   static ButtonStyle AppElevatedButtonStyles = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.backLight,
        iconColor: AppColors.primary
      );
  
}