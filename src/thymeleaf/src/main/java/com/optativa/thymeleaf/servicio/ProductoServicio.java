package com.optativa.thymeleaf.servicio;

import java.util.List;

import com.optativa.thymeleaf.entidad.Producto;

public interface ProductoServicio {
	List<Producto> obtenerProductos();
	Producto obtenerProductoPorId(int id);
	void agregarProducto(Producto producto);
	void actualizarProducto(Producto producto);
	void eliminarProducto(int id);
}

