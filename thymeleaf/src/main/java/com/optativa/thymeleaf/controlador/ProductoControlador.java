package com.optativa.thymeleaf.controlador;

import com.optativa.thymeleaf.modelo.Producto;
import jakarta.validation.Valid;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * @author Hafdala Mehdi Sidi
 */
@Controller
public class ProductoControlador {

    private final List<Producto> listaProductos = new ArrayList<>();

    public ProductoControlador() {
        listaProductos.add(new Producto(1L, "Teclado", 25.99, "Informática"));
        listaProductos.add(new Producto(2L, "Silla de oficina", 89.50, "Mobiliario"));
        listaProductos.add(new Producto(3L, "Cuaderno", 1.75, "Papelería"));
    }

    @GetMapping("/productos")
    public String listarProductos(Model modelo) {
        modelo.addAttribute("listaProductos", listaProductos);
        return "productos";
    }

    @GetMapping("/productos/buscar")
    public String buscarProductos(@RequestParam String query, Model modelo) {
        List<Producto> resultados = listaProductos.stream()
                .filter(p -> p.getNombre().toLowerCase().contains(query.toLowerCase()))
                .collect(Collectors.toList());

        modelo.addAttribute("listaProductos", resultados);
        modelo.addAttribute("query", query);
        return "productos";
    }

    @GetMapping("/productos/{id}")
    public String verDetalle(@PathVariable Long id, Model modelo) {
        Producto producto = listaProductos.stream()
                .filter(p -> p.getId().equals(id))
                .findFirst()
                .orElse(null);

        modelo.addAttribute("producto", producto);
        return "detalleProducto";
    }

    @GetMapping("/productos/nuevo")
    public String mostrarFormularioAlta(Model modelo) {
        modelo.addAttribute("producto", new Producto());
        return "formularioProducto";
    }

    @PostMapping("/productos/nuevo")
    public String darDeAltaProducto(@Valid @ModelAttribute("producto") Producto producto, BindingResult bindingResult) {
        if (bindingResult.hasErrors()) {
            return "formularioProducto";
        }

        producto.setId((long) (listaProductos.size() + 1));
        listaProductos.add(producto);
        return "redirect:/productos";
    }
}
