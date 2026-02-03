package com.optativa.thymeleaf.controlador;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

import com.optativa.thymeleaf.entidad.Producto;
import com.optativa.thymeleaf.entidad.Usuario;
import com.optativa.thymeleaf.servicio.ProductoServicio;
import com.optativa.thymeleaf.servicio.UsuarioServicio;

import jakarta.validation.Valid;

@Controller
public class ProductoControlador {

    private final ProductoServicio productoServicio;
    private final UsuarioServicio usuarioServicio;

    // Inyección por constructor de la implementación (ProductoServicioImpl)
    public ProductoControlador(ProductoServicio productoServicio, UsuarioServicio usuarioServicio) {
        this.productoServicio = productoServicio;
        this.usuarioServicio = usuarioServicio;
    }

    /* ==========================
       SALUDO DE PRUEBA
       ========================== */

    @GetMapping("/saluda")
    public String saludo(@RequestParam(required = false, defaultValue = "Test") String name,
                         Model modelo) {
        modelo.addAttribute("nombre", name);
        return "saludo";
    }

    /* ==========================
       LISTADO Y DETALLE
       ==========================
       Si en el controller pasas un Page<Producto> al modelo, en thymeleaf:

			Para comprobar vacío: productos.empty
			Para iterar: productos.content
        *
        */
    @GetMapping("/productos")
    public String listado(Model model, @PageableDefault(size=20) Pageable page) {
        Page<Producto> productos = productoServicio.obtenerProductoPorPagina(page);
        Usuario usuario = usuarioServicio.obtenerUsuarioConectado();       

        
    	//Page<Producto> productos = Page.empty();
        model.addAttribute("usuario", usuario);
        model.addAttribute("productos", productos);
		model.addAttribute("total", productos.getTotalElements());
        return "lista";
    }

    @GetMapping("/productos/{id}")
    public String obtenerProducto(@PathVariable int id, Model model) {
        Producto p = productoServicio.obtenerProductoPorId(id);
        model.addAttribute("producto", p);
        return "vista";
    }

    /* ==========================
       CREAR
       ========================== */

    // Mostrar formulario vacío para crear
    @GetMapping("/formulario")
    public String mostrarFormCrear(Model model) {
        model.addAttribute("producto", new Producto()); // id = 0
        return "formulario";
    }

    /* ==========================
       EDITAR
       ========================== */

    // Mostrar formulario con datos para editar
    @GetMapping("/productos/{id}/editar")
    public String mostrarFormEditar(@PathVariable int id, Model model) {
        Producto producto = productoServicio.obtenerProductoPorId(id);
        model.addAttribute("producto", producto);
        return "formulario"; // mismo formulario que para crear
    }

    /* ==========================
       GUARDAR (CREAR o EDITAR)
       ========================== */

    @PostMapping("/formulario")
    public String guardarProducto(@Valid Producto producto,
                                  BindingResult bindingResult) {

        // Si hay errores de validación, volvemos al formulario
        if (bindingResult.hasErrors()) {
            return "formulario";
        }

        if (producto.getId() == 0) {
            // Crear nuevo
            productoServicio.agregarProducto(producto);
        } else {
            // Editar existente
            productoServicio.actualizarProducto(producto);
        }

        // PRG: redirigimos para evitar que F5 repita el POST
        return "redirect:/productos";
    }

    /* ==========================
       ELIMINAR
       ========================== */

    // Versión sencilla con GET (para el enlace "Eliminar" del listado)
    @GetMapping("/productos/{id}/eliminar")
    public String eliminarProducto(@PathVariable int id) {
        productoServicio.eliminarProducto(id);
        return "redirect:/productos";
    }
}
