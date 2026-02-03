package com.optativa.thymeleaf.servicio.impl;

import java.util.List;
import java.util.Objects;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.optativa.thymeleaf.entidad.Usuario;
import com.optativa.thymeleaf.entidad.enumerado.Rol;
import com.optativa.thymeleaf.repositorio.UsuarioRepositorio;
import com.optativa.thymeleaf.servicio.UsuarioServicio;



@Service
@Transactional
public class UsuarioServicioImpl implements UsuarioServicio {
	 

    private final UsuarioRepositorio usuarioRepositorio;
    private final PasswordEncoder passwordEncoder;

    public UsuarioServicioImpl(UsuarioRepositorio usuarioRepositorio, PasswordEncoder passwordEncoder) {
        this.usuarioRepositorio = usuarioRepositorio;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public Usuario crear(String nombre, String contrasenaEnClaro, Rol rol) {
        String nombreNorm = normalizarNombre(nombre);
        validarContrasena(contrasenaEnClaro);
        Objects.requireNonNull(rol, "El rol no puede ser null");

        if (usuarioRepositorio.findByNombre(nombreNorm) != null) {
            throw new IllegalArgumentException("Ya existe un usuario con nombre: " + nombreNorm);
        }

        Usuario u = new Usuario();
        u.setNombre(nombreNorm);
        u.setContrasena(passwordEncoder.encode(contrasenaEnClaro));
        u.setRol(rol);

        return usuarioRepositorio.save(u);
    }

    @Override
    public Usuario actualizar(Long id, String nuevoNombre, Rol nuevoRol) {
        Objects.requireNonNull(id, "El id no puede ser null");
        String nuevoNombreNorm = normalizarNombre(nuevoNombre);
        Objects.requireNonNull(nuevoRol, "El rol no puede ser null");

        Usuario u = usuarioRepositorio.findById(id)
                .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado (id=" + id + ")"));

        Usuario existente = usuarioRepositorio.findByNombre(nuevoNombreNorm);
        if (existente != null && !existente.getId().equals(id)) {
            throw new IllegalArgumentException("Ya existe un usuario con nombre: " + nuevoNombreNorm);
        }

        u.setNombre(nuevoNombreNorm);
        u.setRol(nuevoRol);

        return usuarioRepositorio.save(u);
    }

    @Override
    public void cambiarContrasena(Long id, String contrasenaActualEnClaro, String nuevaContrasenaEnClaro) {
        Objects.requireNonNull(id, "El id no puede ser null");
        validarContrasena(contrasenaActualEnClaro);
        validarContrasena(nuevaContrasenaEnClaro);

        Usuario u = usuarioRepositorio.findById(id)
                .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado (id=" + id + ")"));

        if (!passwordEncoder.matches(contrasenaActualEnClaro, u.getContrasena())) {
            throw new IllegalArgumentException("La contraseña actual no es correcta");
        }

        u.setContrasena(passwordEncoder.encode(nuevaContrasenaEnClaro));
        usuarioRepositorio.save(u);
    }

    @Override
    @Transactional(readOnly = true)
    public Usuario obtenerPorId(Long id) {
        Objects.requireNonNull(id, "El id no puede ser null");
        return usuarioRepositorio.findById(id)
                .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado (id=" + id + ")"));
    }

    @Override
    @Transactional(readOnly = true)
    public Usuario obtenerPorNombre(String nombre) {
        String nombreNorm = normalizarNombre(nombre);

        Usuario u = usuarioRepositorio.findByNombre(nombreNorm);
        if (u == null) {
            throw new UsernameNotFoundException("Usuario no encontrado (nombre=" + nombreNorm + ")");
        }
        return u;
    }

    @Override
    @Transactional(readOnly = true)
    public List<Usuario> listar() {
        return usuarioRepositorio.findAll();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<Usuario> listar(Pageable pageable) {
        Objects.requireNonNull(pageable, "El pageable no puede ser null");
        return usuarioRepositorio.findAll(pageable);
    }

    @Override
    public void eliminar(Long id) {
        Objects.requireNonNull(id, "El id no puede ser null");

        if (!usuarioRepositorio.existsById(id)) {
            throw new UsernameNotFoundException("Usuario no encontrado (id=" + id + ")");
        }
        usuarioRepositorio.deleteById(id);
    }

    // =========================
    // Helpers de validación
    // =========================

    private String normalizarNombre(String nombre) {
        if (nombre == null || nombre.isBlank()) {
            throw new IllegalArgumentException("El nombre no puede estar vacío");
        }
        String n = nombre.trim();
        if (n.length() < 3) throw new IllegalArgumentException("El nombre debe tener al menos 3 caracteres");
        if (n.length() > 50) throw new IllegalArgumentException("El nombre no puede superar 50 caracteres");
        return n;
    }

    private void validarContrasena(String contrasena) {
        if (contrasena == null || contrasena.isBlank()) {
            throw new IllegalArgumentException("La contraseña no puede estar vacía");
        }
        if (contrasena.length() < 6) {
            throw new IllegalArgumentException("La contraseña debe tener al menos 6 caracteres");
        }
        // útil si usas BCrypt
        if (contrasena.length() > 72) {
            throw new IllegalArgumentException("La contraseña es demasiado larga");
        }
    }

	@Override
	public Usuario obtenerUsuarioConectado() {
		Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
		if(!(authentication instanceof AnonymousAuthenticationToken)) {
			String nombreUsuarioconectado = authentication.getName();
			return usuarioRepositorio.findByNombre(nombreUsuarioconectado);
		}
		return null;
	}
}
