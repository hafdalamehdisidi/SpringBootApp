package com.optativa.thymeleaf.controlador;

import com.optativa.thymeleaf.modelo.EnvioForm;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

/**
 * @author Hafdala Mehdi Sidi
 */
@Controller
public class EnvioControlador {

    private static final double PESO_MAXIMO_SIN_RECARGO = 5.0;
    private static final double RECARGO_POR_KG_EXTRA = 1.5;
    private static final double PORCENTAJE_RECARGO_URGENTE = 0.5;

    @GetMapping("/envio")
    public String mostrarFormulario(Model modelo) {
        modelo.addAttribute("envio", new EnvioForm());
        return "envio";
    }

    @PostMapping("/envio/calcular")
    public String calcular(@ModelAttribute EnvioForm envio) {
        double costeBase = switch (envio.getDestino()) {
            case "europa" -> 12.0;
            case "internacional" -> 25.0;
            default -> 5.0;
        };

        double recargoPeso = 0.0;
        if (envio.getPeso() > PESO_MAXIMO_SIN_RECARGO) {
            recargoPeso = (envio.getPeso() - PESO_MAXIMO_SIN_RECARGO) * RECARGO_POR_KG_EXTRA;
        }

        double subtotal = costeBase + recargoPeso;

        double recargoUrgente = 0.0;
        if (envio.isUrgente()) {
            recargoUrgente = subtotal * PORCENTAJE_RECARGO_URGENTE;
        }

        envio.setCosteBase(costeBase);
        envio.setRecargoPeso(recargoPeso);
        envio.setRecargoUrgente(recargoUrgente);
        envio.setTotal(subtotal + recargoUrgente);

        return "envio";
    }
}
