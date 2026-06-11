package com.optativa.thymeleaf.modelo;

/**
 * @author Hafdala Mehdi Sidi
 */
public class EnvioForm {

    private double peso;
    private String destino;
    private boolean urgente;

    private Double costeBase;
    private Double recargoPeso;
    private Double recargoUrgente;
    private Double total;

    public double getPeso() {
        return peso;
    }

    public void setPeso(double peso) {
        this.peso = peso;
    }

    public String getDestino() {
        return destino;
    }

    public void setDestino(String destino) {
        this.destino = destino;
    }

    public boolean isUrgente() {
        return urgente;
    }

    public void setUrgente(boolean urgente) {
        this.urgente = urgente;
    }

    public Double getCosteBase() {
        return costeBase;
    }

    public void setCosteBase(Double costeBase) {
        this.costeBase = costeBase;
    }

    public Double getRecargoPeso() {
        return recargoPeso;
    }

    public void setRecargoPeso(Double recargoPeso) {
        this.recargoPeso = recargoPeso;
    }

    public Double getRecargoUrgente() {
        return recargoUrgente;
    }

    public void setRecargoUrgente(Double recargoUrgente) {
        this.recargoUrgente = recargoUrgente;
    }

    public Double getTotal() {
        return total;
    }

    public void setTotal(Double total) {
        this.total = total;
    }
}
