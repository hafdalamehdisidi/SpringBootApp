package com.optativa.thymeleaf.excepciones;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(UsernameNotFoundException.class)
    public String handleUserNotFound(UsernameNotFoundException ex, HttpServletRequest req, Model model) {
        model.addAttribute("titulo", "Usuario no encontrado");
        model.addAttribute("mensaje", ex.getMessage());
        model.addAttribute("path", req.getRequestURI());
        model.addAttribute("status", 404);
        return "error";
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public String handleBadRequest(IllegalArgumentException ex, HttpServletRequest req, Model model) {
        model.addAttribute("titulo", "Petición no válida");
        model.addAttribute("mensaje", ex.getMessage());
        model.addAttribute("path", req.getRequestURI());
        model.addAttribute("status", 400);
        return "error";
    }

    @ExceptionHandler(Exception.class)
    public String handleGeneric(Exception ex, HttpServletRequest req, Model model) {
        model.addAttribute("titulo", "Error inesperado");
        model.addAttribute("mensaje", "Ha ocurrido un error. Inténtalo de nuevo.");
        model.addAttribute("path", req.getRequestURI());
        model.addAttribute("status", 500);
        return "error";
    }
}

