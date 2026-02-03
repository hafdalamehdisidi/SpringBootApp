package com.optativa.thymeleaf.controlador;

import static org.hamcrest.Matchers.hasSize;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;

import com.optativa.thymeleaf.entidad.Producto;
import com.optativa.thymeleaf.servicio.ProductoServicio;

@WebMvcTest(ProductoControlador.class)
class ProductoControladorTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ProductoServicio servicio;   // 🔴 CLAVE: mock del servicio para que el contexto arranque

    @Test
    @DisplayName("GET /formulario devuelve la vista 'formulario' con un Producto en el modelo")
    void mostrarForm_devuelveFormularioConProducto() throws Exception {
        mockMvc.perform(get("/formulario"))
               .andExpect(status().isOk())
               .andExpect(view().name("formulario"))
               .andExpect(model().attributeExists("producto"));
    }

    @Test
    @DisplayName("GET /productos rellena el modelo con listaProductos y muestra 'lista'")
    void listadoProductos() throws Exception {
        when(servicio.obtenerProductos()).thenReturn(
                List.of(new Producto(1, "P1", 10.0, "Cat1"))
        );

        mockMvc.perform(get("/productos"))
               .andExpect(status().isOk())
               .andExpect(view().name("lista"))
               .andExpect(model().attributeExists("listaProductos"))
               .andExpect(model().attribute("listaProductos", hasSize(1)));

        verify(servicio, times(1)).obtenerProductos();
    }
    
    @Test
    void formularioConDatosInvalidos_devuelveMensajesCorrectosEnBindingResult() throws Exception {

        var mvcResult = mockMvc.perform(post("/formulario")
                        .param("id", "1")
                        .param("nombre", "")       // inválido
                        .param("precio", "-5")     // inválido
                        .param("categoria", ""))   // inválido
                .andExpect(view().name("formulario"))
                .andReturn();

        // El BindingResult de "producto" se guarda con esta clave
        BindingResult bindingResult = (BindingResult)
                mvcResult.getModelAndView()
                         .getModel()
                         .get("org.springframework.validation.BindingResult.producto");

        assertNotNull(bindingResult);

        FieldError nombreError = bindingResult.getFieldError("nombre");
        FieldError precioError = bindingResult.getFieldError("precio");
        FieldError categoriaError = bindingResult.getFieldError("categoria");

        assertNotNull(nombreError);
        assertEquals("Nombre no puede estar en blanco", nombreError.getDefaultMessage());

        assertNotNull(precioError);
        assertEquals("El precio tiene que ser positivo", precioError.getDefaultMessage());

        assertNotNull(categoriaError);
        assertEquals("Categoría tiene que tener un valor", categoriaError.getDefaultMessage());
    }
}
