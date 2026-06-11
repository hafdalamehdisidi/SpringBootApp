package com.optativa.thymeleaf.controlador;

import com.optativa.thymeleaf.modelo.Producto;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import java.util.ArrayList;
import java.util.List;

/**
 * @author Hafdala Mehdi Sidi
 */
@Controller
public class ProductoControlador {

    @GetMapping("/productos")
    public String listarProductos(Model modelo) {
        List<Producto> listaProductos = new ArrayList<>();
        // listaProductos.add(new Producto("Teclado", 25.99, "Informática"));
        // listaProductos.add(new Producto("Silla de oficina", 89.50, "Mobiliario"));
        // listaProductos.add(new Producto("Cuaderno", 1.75, "Papelería"));

        modelo.addAttribute("listaProductos", listaProductos);
        return "productos";
    }
}
