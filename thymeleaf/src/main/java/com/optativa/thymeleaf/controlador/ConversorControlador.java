package com.optativa.thymeleaf.controlador;

import com.optativa.thymeleaf.modelo.ConversionTemperatura;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

/**
 * @author Hafdala Mehdi Sidi
 */
@Controller
public class ConversorControlador {

    @GetMapping("/conversor")
    public String mostrarFormulario(Model modelo) {
        modelo.addAttribute("conversion", new ConversionTemperatura());
        return "conversor";
    }

    @PostMapping("/conversor")
    public String convertir(@ModelAttribute("conversion") ConversionTemperatura conversion) {
        double valor = conversion.getValor();
        double resultado;

        if ("CtoF".equals(conversion.getTipoConversion())) {
            resultado = valor * 9 / 5 + 32;
        } else {
            resultado = (valor - 32) * 5 / 9;
        }

        conversion.setResultado(resultado);
        return "conversor";
    }
}
