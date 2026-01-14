package com.optativa.thymeleaf.entidad;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
/**
 * https://spring.io/guides/gs/validating-form-input
 */
@Entity
public class Producto {
		//añadios ID
		@Id
		@GeneratedValue(strategy =GenerationType.AUTO)
		private Integer id;
		@NotBlank(message = "Nombre no puede estar en blanco")
		private String nombre;
		@Positive(message = "El precio tiene que ser positivo")
		private double precio;
		
		@NotBlank(message = "Categoría tiene que tener un valor")
		private String categoria;
		
		public Producto() {}
		
		public Producto(int id, String nombre, double precio, String categoria) {
			super();
			this.id = id;
			this.nombre = nombre;
			this.precio = precio;
			this.categoria = categoria;
		}


		public String getNombre() {
			return nombre;
		}

		public void setNombre(String nombre) {
			this.nombre = nombre;
		}

		public double getPrecio() {
			return precio;
		}

		public void setPrecio(double precio) {
			this.precio = precio;
		}

		public String getCategoria() {
			return categoria;
		}

		public void setCategoria(String categoria) {
			this.categoria = categoria;
		}

		public Integer getId() {
			return id;
		}

		public void setId(Integer id) {
			this.id = id;
		}

		@Override
		public String toString() {
			return "Producto [id=" + id + ", nombre=" + nombre + ", precio=" + precio + ", categoria=" + categoria
					+ "]";
		}
		
			

}
