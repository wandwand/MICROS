;=============================================================================
; Robô Seguidor de Linha - PIC16F628A
; Tarefa 2: Iniciar em marcação, seguir linha, curvar na 1ª bifurcação, parar na 2ª
;=============================================================================

        LIST        p=16F628A
        #include    <p16f628a.inc>

        __CONFIG _INTOSC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _BODEN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

;=============================================================================
; Variáveis
;=============================================================================
CBLOCK 0x70
    AT0
    AT1
    AT2
    FLAG
    CONT11
ENDC

; Sensores
S_ESQ    EQU 0      ; RB0
S_FRENTE EQU 2      ; RB2

; Motores
M_E      EQU 4
M_D      EQU 5

; Bits de FLAG
PRIMEIRA_VEZ EQU 0
SEGUNDA_VEZ  EQU 1

;=============================================================================
; Vetores
;=============================================================================
ORG 0x000
    GOTO INICIO

ORG 0x004
    RETFIE

;=============================================================================
; Inicialização
;=============================================================================
INICIO:
    BANKSEL TRISB
    MOVLW   b'00000111'
    MOVWF   TRISB           ; RB0, RB1, RB2 como entrada (sensores)

    BANKSEL TRISA
    CLRF TRISA              ; PORTA como saída

    BANKSEL CMCON
    MOVLW 0x07
    MOVWF CMCON             ; Desabilita comparadores

    BANKSEL PORTA
    CLRF PORTA

    BANKSEL PORTB
    CLRF PORTB

    CLRF FLAG
    CLRF CONT11

;=============================================================================
; Aguardar início na marcação (Figura 2.a)
;=============================================================================
AGUARDA_INICIO:
    BTFSC PORTB, S_ESQ      ; Aguarda até que o sensor ESQ esteja na linha
    GOTO AGUARDA_INICIO
    BTFSC PORTB, S_FRENTE   ; Aguarda até que o sensor FRENTE esteja na linha
    GOTO AGUARDA_INICIO
    ; Ambos sensores fora da linha = marcação detectada
    CALL DELAY_PEQUENO      ; Pequeno delay para estabilização

;=============================================================================
; LOOP PRINCIPAL
;=============================================================================
MAIN:
    CALL VERIFICA_11        ; Verifica bifurcação
    GOTO LOGICA_NORMAL      ; Segue linha normalmente

;=============================================================================
; Verificação estável do padrão 11 (bifurcação)
;=============================================================================
VERIFICA_11:
    BANKSEL PORTB
    BTFSS PORTB, S_ESQ
    GOTO RESETA_11
    BTFSS PORTB, S_FRENTE
    GOTO RESETA_11

    INCF CONT11, F
    MOVLW .4
    CPFSEQ CONT11
    GOTO LOGICA_NORMAL

    CLRF CONT11
    GOTO TRATA_BIFURCACAO

RESETA_11:
    CLRF CONT11
    RETURN

;=============================================================================
; Tratamento de bifurcação (1ª ou 2ª)
;=============================================================================
TRATA_BIFURCACAO:
    BANKSEL FLAG
    BTFSS FLAG, PRIMEIRA_VEZ
    GOTO BIFURCACAO_1

    BTFSS FLAG, SEGUNDA_VEZ
    GOTO BIFURCACAO_2

    GOTO PARAR

BIFURCACAO_1:
    BSF FLAG, PRIMEIRA_VEZ
    ; Curva à esquerda (ajuste se necessário)
    BANKSEL PORTB
    BCF PORTB, M_E
    BSF PORTB, M_D
    CALL DELAY_CURVA_LONGA
    RETURN

BIFURCACAO_2:
    BSF FLAG, SEGUNDA_VEZ
    ; Avança um pouco antes de parar
    CALL ANDAR_RETO
    CALL DELAY_PEQUENO
    CALL DELAY_PEQUENO
    GOTO PARAR

;=============================================================================
; Lógica normal de seguimento de linha
;=============================================================================
LOGICA_NORMAL:
    BANKSEL PORTB
    BTFSC PORTB, S_FRENTE
    GOTO ANDAR_RETO

    BTFSC PORTB, S_ESQ
    GOTO AJUSTE_ESQ

    ; Perdeu linha: curva leve à esquerda
    BCF PORTB, M_E
    BSF PORTB, M_D
    GOTO MAIN

;=============================================================================
; Comandos de movimento
;=============================================================================
ANDAR_RETO:
    BANKSEL PORTB
    BSF PORTB, M_E
    BSF PORTB, M_D
    RETURN

AJUSTE_ESQ:
    BANKSEL PORTB
    BCF PORTB, M_E
    BSF PORTB, M_D
    RETURN

PARAR:
    BANKSEL PORTB
    BCF PORTB, M_E
    BCF PORTB, M_D
    GOTO $                  ; Loop infinito (parada total)

;=============================================================================
; Delays (ajustar conforme necessidade)
;=============================================================================
DELAY_PEQUENO:
    MOVLW .50
    MOVWF AT1
DP1:
    MOVLW .100
    MOVWF AT0
DP0:
    DECFSZ AT0,F
    GOTO DP0
    DECFSZ AT1,F
    GOTO DP1
    RETURN

DELAY_CURVA_LONGA:
    MOVLW .150              ; Ajuste este valor para a curva
    MOVWF AT2
DL2:
    MOVLW .200
    MOVWF AT1
DL1:
    MOVLW .200
    MOVWF AT0
DL0:
    DECFSZ AT0,F
    GOTO DL0
    DECFSZ AT1,F
    GOTO DL1
    DECFSZ AT2,F
    GOTO DL2
    RETURN

END