import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/utils/utils.dart';

/// Allows to display the current progress of an operation.
class StepProgressIndicator extends StatelessWidget {
  /// The step count.
  final int steps;

  /// The current step.
  final int currentStep;

  /// Steps size.
  final double stepsSize;

  /// Current step size.
  final double currentStepSize;

  /// Creates a new step progress indicator instance.
  const StepProgressIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
    this.stepsSize = 6,
    this.currentStepSize = 10,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (steps - 1) * stepsSize + currentStepSize + 10 * steps,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < steps; i++)
          if (i == currentStep - 1)
            Container(
              color: context.theme.colors.primary,
              width: currentStepSize,
              height: currentStepSize,
            )
          else
            Container(
              color: context.theme.colors.secondary.highlight(amount: 0.25),
              width: stepsSize,
              height: stepsSize,
            ),
      ],
    ),
  );
}
