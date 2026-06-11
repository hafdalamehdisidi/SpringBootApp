package com.optativa.thymeleaf.modelo;

/**
 * @author Hafdala Mehdi Sidi
 */
public class ConversionTemperatura {

    private double valor;
    private String tipoConversion;
    private Double resultado;

    public double getValor() {
        return valor;
    }

    public void setValor(double valor) {
        this.valor = valor;
    }

    public String getTipoConversion() {
        return tipoConversion;
    }

    public void setTipoConversion(String tipoConversion) {
        this.tipoConversion = tipoConversion;
    }

    public Double getResultado() {
        return resultado;
    }

    public void setResultado(Double resultado) {
        this.resultado = resultado;
    }
}
