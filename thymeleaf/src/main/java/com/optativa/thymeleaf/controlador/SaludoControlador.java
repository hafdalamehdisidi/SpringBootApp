package com.optativa.thymeleaf.controlador;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * @author Hafdala Mehdi Sidi
 */

@Controller
public class SaludoControlador {

    @GetMapping("/saludo")
    public String saludo(Model modelo){
        modelo.addAttribute("mensaje", "Bienvenido a Thymeleaf!");
        modelo.addAttribute("nombre", "Ana");
        return "saludo";
    }
}
