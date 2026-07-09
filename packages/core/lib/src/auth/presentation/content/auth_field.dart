import 'package:flutter/material.dart';

import 'auth_styles.dart';

/// Campo padrão das telas de auth: rótulo branco em negrito + caixa
/// translúcida com ícone e hint brancos (visual weberpsetes). Campos de
/// senha ganham o olho de mostrar/ocultar.
class AuthField extends StatefulWidget {
  const AuthField({
    required this.label,
    required this.hint,
    required this.controller,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: AuthStyles.label),
          const SizedBox(height: 10),
          Container(
            alignment: Alignment.centerLeft,
            decoration: AuthStyles.field(context),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscure && !_visible,
              keyboardType: widget.keyboardType,
              onFieldSubmitted: widget.onSubmitted,
              style: AuthStyles.input,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: widget.icon != null
                    ? Icon(widget.icon, color: Colors.white)
                    : null,
                hintText: widget.hint,
                hintStyle: AuthStyles.hint,
                suffixIcon: widget.obscure
                    ? IconButton(
                        icon: Icon(
                          _visible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() => _visible = !_visible),
                      )
                    : null,
              ),
            ),
          ),
        ],
      );
}

/// Botão de destaque das telas de auth (ENTRAR do flyer — verde Setes).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3E9B4F), // SetesColors.green
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  height: 22, width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label.toUpperCase()),
        ),
      );
}
